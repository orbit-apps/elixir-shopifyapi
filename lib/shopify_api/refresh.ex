defmodule ShopifyAPI.Refresh do
  @moduledoc """
  Runs, schedules and de-duplicates refreshes of expiring offline access tokens.

  Wraps `ShopifyAPI.AuthRequest.refresh_offline_access_token/2` with scheduling,
  de-duplication and retry. `ShopifyAPI.AuthToken.fetch/2` is the usual caller.

  ## Entry points

    - `run/1` — synchronous, no retry, no de-duplication. The entry point for scheduled sweeps.
    - `run_in_background/1` — returns immediately; refreshes in a supervised task with retries.
      Skipped if one is already in flight for this shop and app.
    - `await_or_run/1` — waits for a refresh already in flight, or runs one in the calling
      process. Used when the token has expired and the caller needs a fresh one.

  ## De-duplication

  A per-node `Registry` tracks the background refresh in flight for each `{shop_name,
  app_name}`. Only `run_in_background/1` registers; `await_or_run/1` checks the registry but
  does not register when it falls through to refreshing itself, so multiple inline callers can
  refresh concurrently. Concurrent refreshes of the same token are safe — Shopify returns the
  same pair — so de-duplication is an optimisation, not a correctness requirement.

  > #### Concurrent refresh behaviour is observed, not documented {: .warning}
  >
  > Shopify does not document that concurrent refreshes return the same pair. This was measured
  > in CR-2679. Re-verify before the January 2027 cutover.

  ## Failure

  `{:error, :needs_reacquisition}` is returned (never retried) when the refresh token is dead.
  All other failures (assumed to be transient) raise. `run_in_background/1` retries inside its task; `await_or_run/1`
  and `run/1` do not — the caller's own retry (Oban, Phoenix) handles that.

  ## Configuration

      config :shopify_api,
        refresh_threshold_seconds: 300,
        refresh_wait_timeout_ms: :timer.seconds(2),
        refresh_retry: [attempts: 3, backoff_ms: :timer.seconds(1)]

  All three default to the values shown.

    - `:refresh_threshold_seconds` — remaining token life, in seconds, below which `fetch/2`
      starts a background refresh.
    - `:refresh_wait_timeout_ms` — how long `await_or_run/1` waits on an in-flight refresh before
      refreshing itself.
    - `:refresh_retry` — `[attempts: n, backoff_ms: ms]` for background refreshes. Backoff is
      exponential with full jitter.
  """

  require Logger

  alias ShopifyAPI.AppServer
  alias ShopifyAPI.AuthRequest
  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.AuthTokenServer

  @registry ShopifyAPI.RefreshRegistry
  @task_supervisor ShopifyAPI.RefreshTaskSupervisor

  # 5 minutes
  @default_threshold_seconds 300
  @default_wait_timeout_ms :timer.seconds(2)
  @default_retry [attempts: 3, backoff_ms: :timer.seconds(1)]

  @doc """
  Refreshes a token synchronously, without retrying.

  Raises `ShopifyAPI.TokenRefreshError` on failure (assumed to be transient) and
  `ShopifyAPI.TokenPersistenceError` if the new pair could not be stored.
  """
  @spec run(AuthToken.t()) :: AuthToken.ok_t() | AuthToken.needs_reacquisition()
  def run(%AuthToken{refresh_token: nil} = token) do
    raise ArgumentError,
          "#{token.shop_name}:#{token.app_name} has no refresh token; it is a permanent token"
  end

  def run(%AuthToken{} = token) do
    case AppServer.get(token.app_name) do
      {:ok, app} ->
        AuthRequest.refresh_offline_access_token(app, token)

      :error ->
        raise ArgumentError,
              "#{token.app_name} is not a registered app, so #{token.shop_name} cannot refresh"
    end
  end

  @doc """
  Refreshes in the background, unless one is already running for this shop and app.

  Returns `:ok` immediately. Failures surface as a crashed task.
  """
  @spec run_in_background(AuthToken.t()) :: :ok
  def run_in_background(%AuthToken{} = token) do
    Task.Supervisor.start_child(@task_supervisor, fn -> claim_and_refresh(token) end)
    :ok
  end

  @doc """
  Waits for a refresh already in flight, or runs one here if there is none.

  Falls back to refreshing in the calling process when the wait exceeds
  `:refresh_wait_timeout_ms`, or when the in-flight refresh finishes without producing a new
  token.
  """
  @spec await_or_run(AuthToken.t()) :: AuthToken.ok_t() | AuthToken.needs_reacquisition()
  def await_or_run(%AuthToken{} = token) do
    case Registry.lookup(@registry, key(token)) do
      [{pid, _value}] -> await(pid, token)
      [] -> use_replacement_or_run(token)
    end
  end

  @doc """
  Remaining life below which `fetch/2` starts a background refresh, in milliseconds.

  Read from `:refresh_threshold_seconds` (default #{@default_threshold_seconds}) and returned in
  milliseconds to match `ShopifyAPI.AuthToken`'s remaining-life check.
  """
  @spec threshold() :: non_neg_integer()
  def threshold do
    :timer.seconds(
      Application.get_env(:shopify_api, :refresh_threshold_seconds, @default_threshold_seconds)
    )
  end

  @doc """
  Returns cached expiring tokens whose pair is older than `age`.

  Intended for a scheduled sweep. Tokens whose `token_expires_at` is further in the past than
  `age` are included; tokens whose refresh token has already expired are excluded, since no
  refresh can revive them.

  Age is measured from `token_expires_at`, which Shopify sets one hour out on each refresh, so
  it approximates the pair's issue time.

  ## Examples

      stale = ShopifyAPI.Refresh.shops_needing_refresh(Duration.new!(day: 28))
      Enum.each(stale, &MyApp.RefreshWorker.enqueue(&1.shop_name))

  """
  @spec shops_needing_refresh(Duration.t()) :: [AuthToken.t()]
  def shops_needing_refresh(%Duration{} = age) do
    now = DateTime.utc_now()
    issued_before = DateTime.shift(now, Duration.negate(age))

    AuthTokenServer.all()
    |> Map.values()
    |> Enum.filter(&due?(&1, now, issued_before))
  end

  defp due?(%AuthToken{refresh_token: nil}, _now, _issued_before), do: false

  defp due?(%AuthToken{} = token, now, issued_before) do
    refreshable?(token.refresh_token_expires_at, now) and
      older_than?(token.token_expires_at, issued_before)
  end

  # Past its own expiry the refresh token is dead, replay included.
  defp refreshable?(nil, _now), do: true
  defp refreshable?(%DateTime{} = expires_at, now), do: DateTime.after?(expires_at, now)

  # Carries a refresh token but no access-token expiry to date it by. Refreshing repairs that.
  defp older_than?(nil, _issued_before), do: true

  defp older_than?(%DateTime{} = token_expires_at, issued_before),
    do: DateTime.before?(token_expires_at, issued_before)

  defp key(%AuthToken{shop_name: shop_name, app_name: app_name}), do: {shop_name, app_name}

  # Registers as the in-flight refresh for this shop, then refreshes with retry.
  defp claim_and_refresh(token) do
    case Registry.register(@registry, key(token), :refreshing) do
      {:ok, _pid} ->
        Logger.debug("#{__MODULE__} refreshing #{AuthToken.create_key(token)} in the background")
        with_retry(token, 1)

      {:error, {:already_registered, _pid}} ->
        Logger.debug("#{__MODULE__} refresh already in flight for #{AuthToken.create_key(token)}")
        :ok
    end
  end

  defp with_retry(token, attempt) do
    run(token)
  rescue
    # Not a transient failure — do not retry.
    error in ArgumentError ->
      reraise error, __STACKTRACE__

    # Includes a failed write. Shopify keeps the old refresh token live until its replacement is
    # presented, and presenting it again returns the same pair (CR-2679), so a retry recovers the
    # pair that could not be stored.
    error ->
      attempts = Keyword.get(retry_opts(), :attempts, 3)

      if attempt < attempts do
        Logger.debug(
          "#{__MODULE__} refresh of #{AuthToken.create_key(token)} failed on attempt " <>
            "#{attempt} of #{attempts}, backing off"
        )

        Process.sleep(backoff(attempt))

        # Another caller may have refreshed this shop while we backed off.
        if superseded?(token) do
          Logger.debug(
            "#{__MODULE__} #{AuthToken.create_key(token)} was refreshed elsewhere while " <>
              "backing off, abandoning retry"
          )

          :ok
        else
          with_retry(token, attempt + 1)
        end
      else
        Logger.error(
          "#{__MODULE__} gave up refreshing #{token.shop_name}:#{token.app_name} after " <>
            "#{attempts} attempts"
        )

        reraise error, __STACKTRACE__
      end
  end

  defp superseded?(token) do
    case AuthTokenServer.get(token.shop_name, token.app_name) do
      {:ok, cached} -> cached.token != token.token
      {:error, :not_found} -> false
    end
  end

  # Exponential backoff with full jitter.
  defp backoff(attempt) do
    base = Keyword.get(retry_opts(), :backoff_ms, :timer.seconds(1))
    :rand.uniform(max(base, 1) * 2 ** (attempt - 1))
  end

  defp retry_opts, do: Application.get_env(:shopify_api, :refresh_retry, @default_retry)

  defp await(pid, token) do
    ref = Process.monitor(pid)
    Logger.debug("#{__MODULE__} waiting on refresh in flight for #{AuthToken.create_key(token)}")

    receive do
      {:DOWN, ^ref, :process, ^pid, _reason} ->
        use_replacement_or_run(token)
    after
      wait_timeout() ->
        Process.demonitor(ref, [:flush])

        Logger.debug(
          "#{__MODULE__} timed out waiting on refresh of #{AuthToken.create_key(token)}, " <>
            "refreshing here instead"
        )

        use_replacement_or_run(token)
    end
  end

  # Re-reads the cache before refreshing, in case another caller already refreshed this token.
  defp use_replacement_or_run(token) do
    case AuthTokenServer.get(token.shop_name, token.app_name) do
      {:ok, cached} ->
        if cached.token == token.token do
          run(cached)
        else
          Logger.debug(
            "#{__MODULE__} #{AuthToken.create_key(token)} was refreshed elsewhere, using that pair"
          )

          {:ok, cached}
        end

      {:error, :not_found} ->
        run(token)
    end
  end

  defp wait_timeout,
    do: Application.get_env(:shopify_api, :refresh_wait_timeout_ms, @default_wait_timeout_ms)
end
