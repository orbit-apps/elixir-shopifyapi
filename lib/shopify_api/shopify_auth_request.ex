defmodule ShopifyAPI.ShopifyAuthRequest do
  @moduledoc """
    ShopifyAuthRequest.post/3 contains logic to request AuthTokens from Shopify given an App,
    Shop domain, and the auth code from the App install.
  """
  require Logger

  alias ShopifyAPI.{App, JSONSerializer}
  @headers [{"Content-Type", "application/json"}]

  defp access_token_url(domain) do
    d = if ShopifyAPI.bypass_host(), do: ShopifyAPI.bypass_host(), else: domain
    "#{ShopifyAPI.transport()}#{d}/admin/oauth/access_token"
  end

  @spec post(App.t(), String.t(), String.t()) :: {:ok, any()} | {:error, any()}
  def post(%App{} = app, domain, auth_code) do
    http_body = %{
      client_id: app.client_id,
      client_secret: app.client_secret,
      code: auth_code
    }

    Logger.debug(fn -> "#{__MODULE__} requesting token from #{access_token_url(domain)}" end)
    encoded_body = JSONSerializer.encode!(http_body)
    HTTPoison.post(access_token_url(domain), encoded_body, @headers)
  end

  @doc """
    Generates the install URL for an App and a Shop.
  """
  @spec install_uri(App.t(), String.t()) :: String.t()
  def install_uri(%App{} = app, domain) when is_binary(domain) do
    redirect_uri = App.auth_install_uri(app)
    generate_auth_uri(app, domain, redirect_uri)
  end

  @spec auth_uri(App.t(), String.t()) :: String.t()
  def auth_uri(%App{} = app, domain) when is_binary(domain) do
    redirect_uri = App.auth_redirect_uri(app)
    generate_auth_uri(app, domain, redirect_uri)
  end

  def generate_auth_uri(app, domain, redirect_uri) do
    query_params = [
      client_id: app.client_id,
      scope: app.scope,
      redirect_uri: redirect_uri,
      state: app.nonce
    ]

    "https://#{domain}/admin/oauth/authorize?#{URI.encode_query(query_params)}"
  end
end
