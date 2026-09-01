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
    http_body = %{
      client_id: app.client_id,
      client_secret: app.client_secret,
      code: auth_code
    }

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
  callback — before returning it.

  Shopify docs:
    - [Session tokens](https://shopify.dev/docs/apps/build/authentication-authorization/session-tokens/set-up-session-tokens)
    - [Token exchange](https://shopify.dev/docs/apps/build/authentication-authorization/access-tokens/token-exchange)
  """
  @spec request_offline_access_token(App.t(), String.t(), String.t()) ::
          {:ok, AuthToken.t()} | {:error, :failed_fetching_offline_token}
  def request_offline_access_token(app, myshopify_domain, session_token) do
    http_body = %{
      client_id: app.client_id,
      client_secret: app.client_secret,
      grant_type: "urn:ietf:params:oauth:grant-type:token-exchange",
      subject_token: session_token,
      subject_token_type: "urn:ietf:params:oauth:token-type:id_token",
      requested_token_type: "urn:shopify:params:oauth:token-type:offline-access-token"
    }

    access_token_url = myshopify_domain |> base_uri() |> URI.to_string()
    encoded_body = JSONSerializer.encode!(http_body)

    case HTTPoison.post(access_token_url, encoded_body, @headers) do
      {:ok, %{status_code: 200, body: body}} ->
        json = JSONSerializer.decode!(body)
        token = AuthToken.from_auth_request(app, myshopify_domain, json)
        AuthTokenServer.set(token)
        {:ok, token}

      err ->
        Logger.error("error creating token #{inspect(err)}")
        {:error, :failed_fetching_offline_token}
    end
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
        Logger.error("error creating token #{inspect(err)}")
        {:error, :failed_fetching_online_token}
    end
  end
end
