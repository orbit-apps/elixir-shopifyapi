defmodule ShopifyApi.Authentication do
  import Logger, only: [info: 1, warn: 1]

  alias ShopifyApi.Shop
  alias ShopifyApi.ShopServer
  alias ShopifyApi.AuthRequest

  def install_url(%Shop{} = shop) do
    query_params = [
      client_id: shop.client_id,
      scope: "read_orders,read_products,write_products",
      redirect_uri: shop.auth_redirect_uri,
      state: shop.nonce
    ]

    # "https://#{shop}.myshopify.com/admin/oauth/authorize?client_id=#{api_key}&scope=#{scopes}&redirect_uri=#{URI.encode(redirect_uri)}&state=#{nonce}"
    "https://#{shop.domain}/admin/oauth/authorize?#{URI.encode_query(query_params)}"
  end

  def update_token(%Shop{} = shop) do
    # > body: "{\"access_token\":\"3e6ea1b6dc727cccc1ad50fff19e7908\",\"scope\":\"read_orders,write_products\"}",
    case AuthRequest.post(shop) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        info("ShopifyApp [#{shop.domain}] fetched token")
        token = body |> Poison.decode!() |> Map.get("access_token")
        ShopServer.set(%{domain: shop.domain, access_token: token})
        {:ok, token}

      {:ok, %HTTPoison.Response{} = response} ->
        warn("ShopifyApp fetching token code: #{response.status_code}")
        {:error, response.status_code}

      {:error, %HTTPoison.Error{reason: reason}} ->
        warn("ShopifyApp error fetching token: #{inspect(reason)}")
        {:error, reason}
    end
  end
end

defmodule ShopifyApi.AuthRequest do
  alias ShopifyApi.Shop

  @headers [{"Content-Type", "application/json"}]

  defp access_token_url(domain) do
    "https://#{domain}/admin/oauth/access_token"
  end

  def post(%Shop{} = shop) do
    http_body = %{
      client_id: shop.client_id,
      client_secret: shop.client_secret,
      code: shop.code
    }

    HTTPoison.post(access_token_url(shop.domain), Poison.encode!(http_body), @headers)
  end
end
