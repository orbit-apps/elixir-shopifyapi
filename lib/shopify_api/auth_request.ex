defmodule ShopifyAPI.AuthRequest do
  @moduledoc """
  AuthRequest.post/3 contains logic to request AuthTokens from Shopify given an App,
  Shop domain, and the auth code from the App install.
  """
  require Logger

  alias ShopifyAPI.JSONSerializer
  @headers [{"Content-Type", "application/json"}]

  defp access_token_url(domain), do: "#{ShopifyAPI.transport()}#{domain}/admin/oauth/access_token"

  @spec post(ShopifyAPI.App.t(), String.t(), String.t()) :: {:ok, any()} | {:error, any()}
  def post(%ShopifyAPI.App{} = app, domain, auth_code) do
    http_body = %{
      client_id: app.client_id,
      client_secret: app.client_secret,
      code: auth_code
    }

    Logger.debug(fn -> "#{__MODULE__} requesting token from #{access_token_url(domain)}" end)
    encoded_body = JSONSerializer.encode!(http_body)
    HTTPoison.post(access_token_url(domain), encoded_body, @headers)
  end
end
