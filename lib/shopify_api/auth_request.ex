defmodule ShopifyAPI.AuthRequest do
  @moduledoc """
  Requests access tokens from a shop's `/admin/oauth/access_token` endpoint.

  Shopify offers two ways to obtain an access token, and this module implements both.

  ## Authorization code grant

  `post/3` trades the `code` query parameter from an OAuth redirect for a token. It is the
  older flow, driven by `ShopifyAPI.Router`, and it is deliberately thin: it returns the raw
  `HTTPoison` result and stores nothing. `ShopifyAPI.App.fetch_token/3` is what parses that
  response into a `ShopifyAPI.AuthToken` or `ShopifyAPI.UserToken`, and the router then writes
  it to the relevant cache.

  ## Token exchange

  `request_offline_access_token/3` and `request_online_access_token/3` trade a session token
  for an access token, which is how an embedded app gets one without a redirect. Unlike
  `post/3` these parse the response *and* write the result to `ShopifyAPI.AuthTokenServer` or
  `ShopifyAPI.UserTokenServer` themselves. `ShopifyAPI.JWTSessionToken` is the usual caller.

  > #### Only two of the three store what they fetch {: .warning}
  >
  > The two exchange functions populate the caches as a side effect; `post/3` does not. Calling
  > `post/3` and forgetting to store the result leaves the shop authenticated with Shopify but
  > unknown to this library.

  Shopify's documentation:

    - [Access tokens](https://shopify.dev/docs/apps/build/authentication-authorization/access-tokens)
    - [Token exchange](https://shopify.dev/docs/apps/build/authentication-authorization/access-tokens/token-exchange)
  """
  require Logger

  alias ShopifyAPI.App
  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.AuthTokenServer
  alias ShopifyAPI.Config
  alias ShopifyAPI.JSONSerializer
  alias ShopifyAPI.UserToken
  alias ShopifyAPI.UserTokenServer

  @headers [{"Content-Type", "application/json"}, {"Accept", "application/json"}]

  @typedoc """
  Why a migration exchange failed before Shopify revoked the permanent token: the status and
  body of Shopify's response, or the `HTTPoison.Error` reason when no response arrived.
  """
  @type migration_failure :: %{status: non_neg_integer(), body: String.t()} | %{reason: term()}

  @doc """
  Exchanges an OAuth authorization code for an access token.

  Returns the `HTTPoison` result unchanged — the body is unparsed JSON and nothing is written
  to any cache. Prefer `ShopifyAPI.App.fetch_token/3`, which wraps this and returns a token
  struct.
  """
  @spec post(ShopifyAPI.App.t(), String.t() | list(), String.t()) ::
          {:ok, any()} | {:error, any()}
  def post(app, myshopify_domain, auth_code) when is_struct(app, App) do
    http_body =
      request_expiring(%{
        client_id: app.client_id,
        client_secret: app.client_secret,
        code: auth_code
      })

    access_token_url = myshopify_domain |> base_uri() |> URI.to_string()

    Logger.debug("#{__MODULE__} requesting token from #{access_token_url}")
    encoded_body = JSONSerializer.encode!(http_body)

    HTTPoison.post(access_token_url, encoded_body, @headers)
  end

  @spec base_uri(String.t()) :: URI.t()
  def base_uri(myshopify_domain) do
    myshopify_domain
    |> ShopifyAPI.Shop.to_uri()
    # TODO use URI.append_path when we drop 1.14 support
    |> URI.merge("/admin/oauth/access_token")
  end

  @doc """
  Exchanges a session token for the shop's offline access token.

  Writes the token to `ShopifyAPI.AuthTokenServer` — and so through your configured persistence
  callback — before returning it. Returns `{:error, :failed_fetching_offline_token}`, storing
  nothing, when the exchange fails or its response carries an incomplete or inconsistent pair.

  Shopify docs:
    - [Session tokens](https://shopify.dev/docs/apps/build/authentication-authorization/session-tokens/set-up-session-tokens)
    - [Token exchange](https://shopify.dev/docs/apps/build/authentication-authorization/access-tokens/token-exchange)
  """
  @spec request_offline_access_token(App.t(), String.t(), String.t()) ::
          {:ok, AuthToken.t()} | {:error, :failed_fetching_offline_token}
  def request_offline_access_token(app, myshopify_domain, session_token) do
    http_body =
      request_expiring(%{
        client_id: app.client_id,
        client_secret: app.client_secret,
        grant_type: "urn:ietf:params:oauth:grant-type:token-exchange",
        subject_token: session_token,
        subject_token_type: "urn:ietf:params:oauth:token-type:id_token",
        requested_token_type: "urn:shopify:params:oauth:token-type:offline-access-token"
      })

    access_token_url = myshopify_domain |> base_uri() |> URI.to_string()
    encoded_body = JSONSerializer.encode!(http_body)

    with {:ok, %{status_code: 200, body: body}} <-
           HTTPoison.post(access_token_url, encoded_body, @headers),
         json = JSONSerializer.decode!(body),
         token = AuthToken.from_auth_request(app, myshopify_domain, json),
         :ok <- AuthToken.validate_pair(token) do
      AuthTokenServer.set(token)
      {:ok, token}
    else
      # A rejected pair lands here as `{:error, reason}`, so the 200 body and the credentials
      # it carries are never logged.
      err ->
        Logger.error("error creating token #{inspect(sanitize_for_logging(err))}")
        {:error, :failed_fetching_offline_token}
    end
  end

  @doc """
  Trades a token's refresh token for a fresh pair, and stores the result.

  Shopify rotates both halves at once: the response carries a new access token and a new
  refresh token. Both are written to `ShopifyAPI.AuthTokenServer` before returning.

  Returns `{:error, :needs_reacquisition}` when Shopify rejects the refresh token (expired or
  superseded). All other failures (assumed to be transient) raise `ShopifyAPI.TokenRefreshError`.

  `ShopifyAPI.Refresh` wraps this with retry and de-duplication.

  Shopify docs:
    - [Offline access tokens](https://shopify.dev/docs/apps/build/authentication-authorization/access-tokens/offline-access-tokens)
  """
  @spec refresh_offline_access_token(App.t(), AuthToken.t()) ::
          AuthToken.ok_t() | AuthToken.needs_reacquisition()
  def refresh_offline_access_token(app, %AuthToken{refresh_token: refresh_token} = token)
      when is_struct(app, App) and is_binary(refresh_token) do
    http_body = %{
      client_id: app.client_id,
      client_secret: app.client_secret,
      grant_type: "refresh_token",
      refresh_token: refresh_token
    }

    access_token_url = token.shop_name |> base_uri() |> URI.to_string()
    encoded_body = JSONSerializer.encode!(http_body)

    Logger.debug("#{__MODULE__} refreshing token for #{AuthToken.create_key(token)}")

    case HTTPoison.post(access_token_url, encoded_body, @headers) do
      {:ok, %{status_code: 200, body: body}} ->
        refreshed = body |> decode_body!(token) |> refreshed_token!(token)

        AuthTokenServer.set(refreshed)

        Logger.debug(
          "#{__MODULE__} refreshed #{AuthToken.create_key(token)}, access token now expires " <>
            "#{refreshed.token_expires_at}, refresh token #{refreshed.refresh_token_expires_at}"
        )

        {:ok, refreshed}

      # Refresh token rejected — expired or superseded.
      {:ok, %{status_code: 401}} ->
        Logger.warning(
          "#{__MODULE__} refresh token rejected for #{token.shop_name}:#{token.app_name}"
        )

        {:error, :needs_reacquisition}

      other ->
        raise ShopifyAPI.TokenRefreshError,
          message:
            "Refreshing #{token.shop_name}:#{token.app_name} failed: " <>
              "#{inspect(sanitize_for_logging(other))}"
    end
  end

  @doc """
  Exchanges a shop's permanent offline token for its first expiring pair.

  This is the one-time migration of a shop that installed before your app began requesting
  expiring tokens. It always requests an expiring pair, whatever `:offline_tokens` is set to,
  and writes the new pair to `ShopifyAPI.AuthTokenServer` — and so through your persistence
  callback — before returning.

  With `offline_tokens: :exchange_permanent`, `ShopifyAPI.AuthToken.fetch/2` calls it for you
  the first time it reads a shop's permanent token. To move shops that make no API calls, run
  it once per shop from a sweep over the permanent tokens still in your storage:

      ShopifyAPI.AuthTokenServer.all()
      |> Map.values()
      |> Enum.filter(&is_nil(&1.refresh_token))
      |> Enum.each(fn token ->
        {:ok, app} = ShopifyAPI.AppServer.get(token.app_name)
        ShopifyAPI.AuthRequest.migrate_offline_access_token(app, token)
      end)

  ## No second chance

  Shopify revokes the permanent token in the same step that issues the expiring pair, and the
  spent token cannot be re-presented, so unlike a refresh there is no replay. The failure modes
  split around the moment the exchange succeeds:

    - **Before it succeeds** — a refused or failed exchange leaves the permanent token intact,
      so the shop is safe to skip and the batch safe to retry. These return `{:error, _}`.
    - **After it succeeds** — an unusable response or a failed write leaves the shop with no
      working credential, recoverable only by a merchant reinstall. These raise
      `ShopifyAPI.TokenMigrationError`, which is worth paging on.

  ## Returns

    - `{:ok, token}` — migrated and stored.
    - `{:error, :already_expiring}` — the token already carries a refresh token, so there is
      nothing to migrate. No request is made, which lets a sweep run over every token and skip
      the ones already moved.
    - `{:error, :invalid_subject_token}` — Shopify rejected the subject token as already spent
      (`400 invalid_subject_token`). The shop was migrated already, by an earlier run or another
      writer, so a re-run skips it cleanly.
    - `{:error, {:failed_migrating_offline_token, failure}}` — the exchange failed for another
      reason before the old token was revoked. Safe to retry. `failure` is a
      `t:migration_failure/0`: Shopify's status and body, or the connection error when Shopify
      never answered.

  Raises `ShopifyAPI.TokenMigrationError` when the exchange succeeds but its pair cannot be
  stored or is unusable — see above.

  Shopify docs:
    - [Migrate to expiring offline access tokens](https://shopify.dev/docs/apps/build/authentication-authorization/migrate-to-expiring-offline-access-tokens) — the exchange parameters, under "Cycle existing tokens without waiting for a merchant"
    - [Token exchange](https://shopify.dev/docs/apps/build/authentication-authorization/access-tokens/token-exchange)
  """
  @spec migrate_offline_access_token(App.t(), AuthToken.t()) ::
          AuthToken.ok_t()
          | {:error, :already_expiring | :invalid_subject_token}
          | {:error, {:failed_migrating_offline_token, migration_failure()}}
  def migrate_offline_access_token(_app, %AuthToken{refresh_token: refresh_token})
      when not is_nil(refresh_token),
      do: {:error, :already_expiring}

  def migrate_offline_access_token(app, %AuthToken{refresh_token: nil} = token)
      when is_struct(app, App) do
    http_body = %{
      client_id: app.client_id,
      client_secret: app.client_secret,
      grant_type: "urn:ietf:params:oauth:grant-type:token-exchange",
      subject_token: token.token,
      subject_token_type: "urn:shopify:params:oauth:token-type:offline-access-token",
      requested_token_type: "urn:shopify:params:oauth:token-type:offline-access-token",
      expiring: 1
    }

    access_token_url = token.shop_name |> base_uri() |> URI.to_string()
    encoded_body = JSONSerializer.encode!(http_body)

    Logger.debug("#{__MODULE__} migrating #{AuthToken.create_key(token)} to an expiring token")

    case HTTPoison.post(access_token_url, encoded_body, @headers) do
      # The exchange succeeded, so Shopify has revoked the permanent token: from here a bad body
      # or a failed write is unrecoverable and raises, rather than returning a skippable error.
      {:ok, %{status_code: 200, body: body}} ->
        migrated = body |> decode_migrated!(token) |> migrated_token!(token)
        store_migrated!(migrated)

        Logger.info(
          "#{__MODULE__} migrated #{AuthToken.create_key(token)} to an expiring token, access " <>
            "token now expires #{migrated.token_expires_at}"
        )

        {:ok, migrated}

      # A spent subject token: this shop was migrated already, so the caller can skip it. It may
      # be a harmless re-run, or a shop stranded by an earlier lost write — the library cannot
      # tell the two apart, so it surfaces the fact and leaves the decision to the caller.
      {:ok, %{status_code: 400, body: body}} = err ->
        if invalid_subject_token?(body) do
          Logger.warning(
            "#{__MODULE__} #{AuthToken.create_key(token)} was already migrated " <>
              "(invalid_subject_token); skipping. Reacquire it if it has no working token."
          )

          {:error, :invalid_subject_token}
        else
          migration_failed(err)
        end

      err ->
        migration_failed(err)
    end
  end

  # Decodes a refresh response body. The decode error is dropped rather than quoted, since it can
  # carry the body and so the credentials in it.
  @spec decode_body!(String.t(), AuthToken.t()) :: term()
  defp decode_body!(body, token) do
    case JSONSerializer.decode(body) do
      {:ok, json} ->
        json

      _error ->
        raise ShopifyAPI.TokenRefreshError,
          message:
            "Refresh for #{token.shop_name}:#{token.app_name} returned a body that is not JSON"
    end
  end

  # Builds the refreshed token from a `refresh_token` grant response.
  #
  # A refresh always returns a complete rotating pair: a new access token, and a new refresh
  # token that outlives it. Requiring all four fields here catches an incomplete response at
  # the source, rather than storing a token with nil expiries and tripping over it later.
  @spec refreshed_token!(map(), AuthToken.t()) :: AuthToken.t()
  defp refreshed_token!(
         %{
           "access_token" => access_token,
           "expires_in" => expires_in,
           "refresh_token" => refresh_token,
           "refresh_token_expires_in" => refresh_token_expires_in
         },
         token
       )
       when is_binary(access_token) and is_integer(expires_in) and
              is_binary(refresh_token) and is_integer(refresh_token_expires_in) do
    refreshed =
      AuthToken.apply_refresh(
        token,
        access_token,
        expires_in,
        refresh_token,
        refresh_token_expires_in
      )

    # Guards against a refresh token that expires no later than the access token it renews,
    # which would strand the shop on its next refresh.
    if AuthToken.refresh_outlives_access?(refreshed) do
      refreshed
    else
      raise ShopifyAPI.TokenRefreshError,
        message:
          "Refresh for #{token.shop_name}:#{token.app_name} returned a refresh token expiring " <>
            "at #{refreshed.refresh_token_expires_at}, no later than its access token at " <>
            "#{refreshed.token_expires_at}"
    end
  end

  defp refreshed_token!(_attrs, token) do
    raise ShopifyAPI.TokenRefreshError,
      message: "Refresh for #{token.shop_name}:#{token.app_name} returned an incomplete pair"
  end

  # Decodes a migration response body. Past a 200 the permanent token is already revoked, so an
  # unusable body is unrecoverable and raises `TokenMigrationError` rather than returning.
  @spec decode_migrated!(String.t(), AuthToken.t()) :: term()
  defp decode_migrated!(body, token) do
    case JSONSerializer.decode(body) do
      {:ok, json} ->
        json

      _error ->
        raise ShopifyAPI.TokenMigrationError,
          message:
            "Migration of #{AuthToken.create_key(token)} returned a body that is not JSON; the " <>
              "old token is revoked and the shop must reinstall"
    end
  end

  # Builds the migrated token from the exchange response. Like a refresh, a migration must return
  # a complete rotating pair; unlike a refresh, an incomplete one strands the shop rather than
  # merely failing, so this raises `TokenMigrationError`.
  @spec migrated_token!(map(), AuthToken.t()) :: AuthToken.t()
  defp migrated_token!(
         %{
           "access_token" => access_token,
           "expires_in" => expires_in,
           "refresh_token" => refresh_token,
           "refresh_token_expires_in" => refresh_token_expires_in
         },
         token
       )
       when is_binary(access_token) and is_integer(expires_in) and
              is_binary(refresh_token) and is_integer(refresh_token_expires_in) do
    migrated =
      AuthToken.apply_refresh(
        token,
        access_token,
        expires_in,
        refresh_token,
        refresh_token_expires_in
      )

    if AuthToken.refresh_outlives_access?(migrated) do
      migrated
    else
      raise ShopifyAPI.TokenMigrationError,
        message:
          "Migration of #{AuthToken.create_key(token)} returned a refresh token expiring no " <>
            "later than its access token; the old token is revoked and the shop must reinstall"
    end
  end

  defp migrated_token!(_attrs, token) do
    raise ShopifyAPI.TokenMigrationError,
      message:
        "Migration of #{AuthToken.create_key(token)} returned an incomplete pair; the old token " <>
          "is revoked and the shop must reinstall"
  end

  # Stores the migrated pair, turning a write failure into the loud, unrecoverable case it is:
  # the exchange already revoked the permanent token, so a lost write leaves the shop with no
  # credential at all. Only the failure's type is named, never its message — a persistence error
  # can carry the token it was writing, and this message reaches logs and pagers. See
  # `ShopifyAPI.AuthTokenServer`, which keeps the same contents out of its own errors.
  @spec store_migrated!(AuthToken.t()) :: :ok
  defp store_migrated!(token) do
    AuthTokenServer.set(token)
  rescue
    error ->
      reraise ShopifyAPI.TokenMigrationError.exception(
                message:
                  "Migrated #{AuthToken.create_key(token)} but could not store the new pair " <>
                    "(#{inspect(error.__struct__)}); the old token is revoked and the shop is " <>
                    "locked out until it reinstalls"
              ),
              __STACKTRACE__
  end

  # A failure before the exchange succeeded, so the permanent token is intact. The sanitized
  # result is returned as well as logged, so a caller can tell a refused exchange from an outage.
  defp migration_failed(err) do
    failure = sanitize_for_logging(err)
    Logger.error("error migrating token #{inspect(failure)}")
    {:error, {:failed_migrating_offline_token, failure}}
  end

  # Whether a token-endpoint error body is a spent subject token, the signal that a shop has
  # already been migrated.
  defp invalid_subject_token?(body) do
    match?({:ok, %{"error" => "invalid_subject_token"}}, JSONSerializer.decode(body))
  end

  # Reduces an HTTP result to the fields safe to log or surface in an exception, dropping the
  # request (which carries the client secret and token).
  defp sanitize_for_logging({:ok, %{status_code: status, body: body}}),
    do: %{status: status, body: body}

  defp sanitize_for_logging({:error, %HTTPoison.Error{reason: reason}}), do: %{reason: reason}
  defp sanitize_for_logging(other), do: other

  # Adds the `expiring` flag to new token requests unless `:offline_tokens` is `:permanent`.
  # Refresh grants do not accept it.
  defp request_expiring(http_body) do
    if Config.expiring?(), do: Map.put(http_body, :expiring, 1), else: http_body
  end

  @doc """
  Exchanges a session token for a staff member's online access token.

  The online counterpart of `request_offline_access_token/3`; writes to
  `ShopifyAPI.UserTokenServer` before returning. The user the token belongs to is taken from
  the exchange response, not from the arguments.

  Shopify docs:
    - [Session tokens](https://shopify.dev/docs/apps/build/authentication-authorization/session-tokens/set-up-session-tokens)
    - [Token exchange](https://shopify.dev/docs/apps/build/authentication-authorization/access-tokens/token-exchange)
  """
  @spec request_online_access_token(App.t(), String.t(), String.t()) ::
          {:ok, UserToken.t()} | {:error, :failed_fetching_online_token}
  def request_online_access_token(app, myshopify_domain, session_token) do
    http_body = %{
      client_id: app.client_id,
      client_secret: app.client_secret,
      grant_type: "urn:ietf:params:oauth:grant-type:token-exchange",
      subject_token: session_token,
      subject_token_type: "urn:ietf:params:oauth:token-type:id_token",
      requested_token_type: "urn:shopify:params:oauth:token-type:online-access-token"
    }

    access_token_url = myshopify_domain |> base_uri() |> URI.to_string()
    encoded_body = JSONSerializer.encode!(http_body)

    case HTTPoison.post(access_token_url, encoded_body, @headers) do
      {:ok, %{status_code: 200, body: body}} ->
        json = JSONSerializer.decode!(body)
        user_token = UserToken.from_auth_request(app, myshopify_domain, json)
        UserTokenServer.set(user_token)
        {:ok, user_token}

      err ->
        Logger.error("error creating token #{inspect(sanitize_for_logging(err))}")
        {:error, :failed_fetching_online_token}
    end
  end
end
