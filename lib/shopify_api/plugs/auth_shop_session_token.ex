defmodule ShopifyAPI.Plugs.AuthShopSessionToken do
  @moduledoc """
  A Plug to handle authenticating the Shop Admin JWT from Shopify.

  ## Example Installations

  Add this plug in a pipeline for your Shop Admin API.

  ```elixir
  pipeline :shop_admin_api do
    plug :accepts, ["json"]
    plug UpSell.Plugs.AuthShopSessionToken
  end
  ```
  """

  import Plug.Conn

  require Logger

  def init(opts), do: opts

  def call(conn, _options) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, app} <- get_app_from_token(token),
         {true, jwt, _jws} <- verify_token(token, app.client_secret),
         {:ok, my_shopify_domain} <- get_my_shopify_domain_from_jwt(jwt),
         {:ok, shop} <- ShopifyAPI.ShopServer.get(my_shopify_domain),
         {:ok, auth_token} <- ShopifyAPI.AuthTokenServer.get(my_shopify_domain, app.name) do
      conn
      |> assign(:app, app)
      |> assign(:shop, shop)
      |> assign(:auth_token, auth_token)
    else
      error ->
        Logger.debug("Could not authenticate #{inspect(error)}")

        conn
        |> resp(401, "Not Authorized.")
        |> halt()
    end
  end

  defp verify_token(token, client_secret) do
    jwk = JOSE.JWK.from_oct(client_secret)
    JOSE.JWT.verify_strict(jwk, ["HS256"], token)
  end

  defp get_app_from_token(token) do
    with %JOSE.JWT{fields: %{"aud" => client_id}} <- JOSE.JWT.peek_payload(token),
         {:ok, app} <- ShopifyAPI.AppServer.get_by_client_id(client_id) do
      {:ok, app}
    else
      _ -> {:error, "Audience claim is not a valid App clientId."}
    end
  end

  defp get_my_shopify_domain_from_jwt(%JOSE.JWT{fields: %{"dest" => shop_url}}) do
    shop_url
    |> URI.parse()
    |> Map.get(:host)
    |> case do
      shop_name when is_binary(shop_name) -> {:ok, shop_name}
      _ -> {:error, "Shop name not found"}
    end
  end
end
