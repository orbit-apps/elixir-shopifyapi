defmodule ShopifyAPI.AuthRequest do
  @moduledoc """
  AuthRequest.post/3 contains logic to request AuthTokens from Shopify given an App,
  Shop domain, and the auth code from the App install.
  """
  require Logger

  alias ShopifyAPI.App
  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.AuthTokenServer
  alias ShopifyAPI.JSONSerializer
  alias ShopifyAPI.UserToken
  alias ShopifyAPI.UserTokenServer

  @headers [{"Content-Type", "application/json"}, {"Accept", "application/json"}]

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
  Shopify docs:
    - https://shopify.dev/docs/apps/build/authentication-authorization/session-tokens/set-up-session-tokens
    - https://shopify.dev/docs/apps/build/authentication-authorization/access-tokens/token-exchange
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
  Shopify docs:
    - https://shopify.dev/docs/apps/build/authentication-authorization/session-tokens/set-up-session-tokens
    - https://shopify.dev/docs/apps/build/authentication-authorization/access-tokens/token-exchange
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
