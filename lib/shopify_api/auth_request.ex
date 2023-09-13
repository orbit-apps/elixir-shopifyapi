defmodule ShopifyAPI.AuthRequest do
  @moduledoc """
  AuthRequest.post/3 contains logic to request AuthTokens from Shopify given an App,
  Shop domain, and the auth code from the App install.
  """
  require Logger

  alias ShopifyAPI.App
  alias ShopifyAPI.JSONSerializer

  @headers [{"Content-Type", "application/json"}]

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

  if Mix.env() == :test or Mix.env() == :dev do
    def base_uri(myshopify_domain) do
      {myshopify_domain, port} =
        if String.match?(myshopify_domain, ~R/.*:.*/) do
          [domain, str_port] = String.split(myshopify_domain, ":")
          {domain, String.to_integer(str_port)}
        else
          {myshopify_domain, 443}
        end

      %URI{
        scheme: ShopifyAPI.transport(),
        port: port,
        host: myshopify_domain,
        path: "/admin/oauth/access_token"
      }
    end
  else
    def base_uri(myshopify_domain) do
      %URI{
        scheme: ShopifyAPI.transport(),
        port: 443,
        host: myshopify_domain,
        path: "/admin/oauth/access_token"
      }
    end
  end
end
