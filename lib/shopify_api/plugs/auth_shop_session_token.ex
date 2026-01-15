defmodule ShopifyAPI.Plugs.AuthShopSessionToken do
  @moduledoc """
  A Plug to handle authenticating the Shop Admin JWT from Shopify.

  ## Example Installations

  Add this plug in a pipeline for your Shop Admin API.

  ```elixir
  pipeline :shop_admin_api do
    plug :accepts, ["json"]
    plug ShopifyAPI.Plugs.AuthShopSessionToken
  end
  ```
  """

  import Plug.Conn

  require Logger

  alias ShopifyAPI.AuthTokenServer
  alias ShopifyAPI.JWTSessionToken
  alias ShopifyAPI.ShopServer
  alias ShopifyAPI.UserToken

  def init(opts), do: opts

  def call(conn, _options) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, app} <- JWTSessionToken.app(token),
         {true, jwt, _jws} <- JWTSessionToken.verify(token, app.client_secret),
         {:ok, myshopify_domain} <- JWTSessionToken.myshopify_domain(jwt),
         {:ok, user_id} <- JWTSessionToken.user_id(jwt),
         {:ok, shop} <- ShopServer.get(myshopify_domain),
         {:ok, auth_token} <- AuthTokenServer.get(myshopify_domain, app.name),
         {:ok, user_token} <- get_user_token(jwt, token) do
      conn
      |> assign(:app, app)
      |> assign(:shop, shop)
      |> assign(:auth_token, auth_token)
      |> assign(:user_id, user_id)
      |> assign(:user_token, user_token)
    else
      error ->
        Logger.debug("Could not authenticate shop #{inspect(error)}")

        conn
        |> resp(401, "Not Authorized.")
        |> halt()
    end
  end

  defp get_user_token(jwt, token) do
    with {:ok, app} <- JWTSessionToken.app(jwt),
         {:ok, myshopify_domain} <- JWTSessionToken.myshopify_domain(jwt),
         {:ok, user_id} <- JWTSessionToken.user_id(jwt) do
      UserToken.get_user_token(app, myshopify_domain, user_id, token)
    else
      error ->
        Logger.warning("failed getting required information from the JWT #{inspect(error)}")
        {:error, :invalid_session_token}
    end
  end
end
