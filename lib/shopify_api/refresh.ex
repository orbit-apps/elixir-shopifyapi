defmodule ShopifyAPI.Refresh do
  @moduledoc """
  Runs, schedules and de-duplicates refreshes of expiring offline access tokens, and exchanges
  of permanent ones.

  Wraps `ShopifyAPI.AuthRequest.refresh_offline_access_token/2` with scheduling,
  de-duplication and retry, and `ShopifyAPI.AuthRequest.migrate_offline_access_token/2` with
  de-duplication. `ShopifyAPI.AuthToken.fetch/2` is the usual caller.

  ## Entry points

    - `run/1` — synchronous, no retry, no de-duplication. The entry point for scheduled sweeps.
    - `run_in_background/1` — returns immediately; refreshes in a supervised task with retries.
      Skipped if one is already in flight for this shop and app.
    - `await_or_run/1` — waits for a refresh already in flight, or runs one in the calling
      process. Used when the token has expired and the caller needs a fresh one.
    - `await_or_exchange/1` — exchanges a permanent token for an expiring pair, or waits for the
      exchange already in flight. Used when `:offline_tokens` is `:exchange_permanent`.

  ## De-duplication

  A per-node `Registry` tracks the refresh or exchange in flight for each `{shop_name,
  app_name}`. Of the refresh entry points only `run_in_background/1` registers; `await_or_run/1`
  checks the registry but does not register when it falls through to refreshing itself, so
  multiple inline callers can refresh concurrently. Concurrent refreshes of the same token are
  safe — Shopify returns the same pair — so de-duplication is an optimisation, not a correctness
  requirement.

  Exchanges are the opposite. Shopify revokes the permanent token as it issues the pair, so a
  second exchange of the same token fails with a spent subject token. `await_or_exchange/1`
  always registers, and callers that find an exchange in flight wait for it however long it
  takes, then start over under a fresh claim. Only the caller holding the claim talks to
  Shopify. A token is either permanent or expiring, so refreshes and exchanges share the
  registry and its keys.

  > #### Concurrent refresh behaviour is observed, not documented {: .warning}
  >
  > Shopify does not document that concurrent refreshes return the same pair. This was measured
  > in CR-2679. Re-verify before the January 2027 cutover.

  ## Other writers

  De-duplication covers this node only. Another application sharing your token storage can
  refresh or exchange a shop's token too, and its pair never reaches this cache. Refreshing
  from the stale pair fails once that application has presented its new refresh token, and
  exchanging a permanent token it already exchanged fails as spent.

  Every entry point except `run/1` therefore calls `ShopifyAPI.AuthTokenServer.reload/2`
  immediately before refreshing or exchanging, and returns the stored token instead when it has
  moved on from the one it was handed. It returns it as stored, possibly near or past expiry
  itself; `ShopifyAPI.AuthToken.fetch/2` resolves it again. That needs the `get` persistence callback; without it
  the reload is a cache read, and a token changed elsewhere ends in
  `{:error, :needs_reacquisition}`. A change landing between the reload and the request does
  too.

  ## Failure

  `{:error, :needs_reacquisition}` is returned (never retried) when the refresh token is dead,
  or the permanent token was already spent. All other failures (assumed to be transient) raise.
  `run_in_background/1` retries inside its task; `await_or_run/1`, `await_or_exchange/1` and
  `run/1` do not — the caller's own retry (Oban, Phoenix) handles that.

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

  Refreshes the token it is handed, without first checking storage for a newer one.

  Raises `ShopifyAPI.TokenRefreshError` on failure (assumed to be transient) and
  `ShopifyAPI.TokenPersistenceError` if the new pair could not be stored.
  """
  @spec run(AuthToken.t()) :: AuthToken.ok_t() | AuthToken.needs_reacquisition()
  def run(%AuthToken{refresh_token: nil} = token) do
    raise ArgumentError,
          "#{token.shop_name}:#{token.app_name} has no refresh token; it is a permanent token"
  end

  def run(%AuthToken{} = token) do
    token
    |> fetch_app!("refresh")
    |> AuthRequest.refresh_offline_access_token(token)
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
  Exchanges a permanent token for an expiring pair, or waits for the exchange already in flight.

  Wraps `ShopifyAPI.AuthRequest.migrate_offline_access_token/2` for
  `ShopifyAPI.AuthToken.fetch/2`, which calls it when `:offline_tokens` is
  `:exchange_permanent`. At most one exchange runs per shop and app; every other caller waits
  for it, then takes the pair it stored. There is no timeout fallback, since a second exchange
  of the same token would fail. When the exchange ahead of a caller stores no pair, that caller
  exchanges the token itself rather than assuming why, so it gets Shopify's own answer — and it
  does so under the same claim, so the callers behind it still wait rather than pile on.

  The exchange runs in a supervised task, so it finishes and stores its pair even if the caller
  exits while waiting — abandoning it after Shopify revokes the permanent token would lock the
  shop out.

  Returns `{:error, :needs_reacquisition}` when Shopify reports the permanent token already
  spent. Raises `ShopifyAPI.TokenRefreshError` when the exchange fails before Shopify revokes
  the permanent token, which is safe to retry, and lets `ShopifyAPI.TokenMigrationError` from a
  failure after it propagate.

  > #### Exchange after the cutover is observed, not documented {: .warning}
  >
  > Shopify does not say whether a permanent token can still be exchanged once it stops
  > accepting permanent tokens on 1 January 2027. In CR-2722, a public app created after April
  > 2026 — whose permanent tokens the Admin API already refuses with a `403` — could still
  > exchange one for an expiring pair. This relies on existing apps behaving the same way after
  > the cutover. If they do not, the failure raises `ShopifyAPI.TokenRefreshError` on every fetch
  > of that shop.
  """
  @spec await_or_exchange(AuthToken.t()) :: AuthToken.ok_t() | AuthToken.needs_reacquisition()
  def await_or_exchange(%AuthToken{refresh_token: nil} = token) do
    task = Task.Supervisor.async_nolink(@task_supervisor, fn -> claim_and_exchange(token) end)

    case Task.yield(task, :infinity) do
      {:ok, {:in_flight, pid}} -> await_exchange(pid, token)
      {:ok, {:raised, exception, stacktrace}} -> reraise exception, stacktrace
      {:ok, result} -> result
      {:exit, reason} -> exit(reason)
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

  defp fetch_app!(token, action) do
    case AppServer.get(token.app_name) do
      {:ok, app} ->
        app

      :error ->
        raise ArgumentError,
              "#{token.app_name} is not a registered app, so #{token.shop_name} cannot #{action}"
    end
  end

  # Registers as the in-flight exchange for this shop, then exchanges. Runs in its own task, and
  # returns an exception rather than raising it so the caller can reraise it without a crash
  # report.
  defp claim_and_exchange(token) do
    case Registry.register(@registry, key(token), :exchanging) do
      {:ok, _pid} ->
        exchange_unless_replaced(token)

      {:error, {:already_registered, pid}} ->
        Logger.debug(
          "#{__MODULE__} exchange already in flight for #{AuthToken.create_key(token)}"
        )

        {:in_flight, pid}
    end
  rescue
    exception -> {:raised, exception, __STACKTRACE__}
  end

  # Reloads first: an exchange that finished between the caller's read and this claim, here or
  # in another application, has already replaced the permanent token, which can no longer be
  # exchanged.
  defp exchange_unless_replaced(token) do
    case AuthTokenServer.reload(token.shop_name, token.app_name) do
      {:ok, %AuthToken{refresh_token: nil} = cached} -> exchange(cached)
      {:ok, cached} -> {:ok, cached}
      {:error, :not_found} -> exchange(token)
    end
  end

  defp exchange(token) do
    Logger.debug("#{__MODULE__} exchanging permanent token for #{AuthToken.create_key(token)}")

    case token |> fetch_app!("exchange") |> AuthRequest.migrate_offline_access_token(token) do
      {:ok, _exchanged} = ok ->
        ok

      # Spent by another application, whose pair the reload before this exchange did not find.
      {:error, :invalid_subject_token} ->
        {:error, :needs_reacquisition}

      {:error, :failed_migrating_offline_token} ->
        raise ShopifyAPI.TokenRefreshError,
          message:
            "Exchanging the permanent token for #{AuthToken.create_key(token)} failed; it was " <>
              "not revoked, so a retry is safe"
    end
  end

  # Waits for another caller's exchange to finish, then starts over. Starting over rather than
  # reading the cache once is what keeps a waiter's answer truthful: a cache still holding the
  # permanent token says only that the exchange did not store a pair, not whether the token was
  # spent, revoked or never presented. The next round asks Shopify, which does distinguish them.
  # It costs a request only when the exchange ahead failed, and only one waiter makes it — the
  # rest queue behind that round's claim.
  defp await_exchange(pid, token) do
    ref = Process.monitor(pid)
    Logger.debug("#{__MODULE__} waiting on exchange in flight for #{AuthToken.create_key(token)}")

    receive do
      {:DOWN, ^ref, :process, ^pid, _reason} -> await_or_exchange(token)
    end
  end

  # Registers as the in-flight refresh for this shop, then refreshes with retry unless storage
  # already holds a newer pair.
  defp claim_and_refresh(token) do
    case Registry.register(@registry, key(token), :refreshing) do
      {:ok, _pid} ->
        if superseded?(token) do
          Logger.debug(
            "#{__MODULE__} #{AuthToken.create_key(token)} was refreshed elsewhere, skipping"
          )

          :ok
        else
          Logger.debug(
            "#{__MODULE__} refreshing #{AuthToken.create_key(token)} in the background"
          )

          with_retry(token, 1)
        end

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
    case AuthTokenServer.reload(token.shop_name, token.app_name) do
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

  # Reloads before refreshing, in case another caller or application already refreshed this
  # token.
  defp use_replacement_or_run(token) do
    case AuthTokenServer.reload(token.shop_name, token.app_name) do
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
