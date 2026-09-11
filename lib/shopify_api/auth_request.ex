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

  # Reduces an HTTP result to the fields safe to log or surface in an exception, dropping the
  # request (which carries the client secret and token).
  defp sanitize_for_logging({:ok, %{status_code: status, body: body}}),
    do: %{status: status, body: body}

  defp sanitize_for_logging({:error, %HTTPoison.Error{reason: reason}}), do: %{reason: reason}
  defp sanitize_for_logging(other), do: other

  # Adds the `expiring` flag to new token requests. Refresh grants do not accept it.
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
