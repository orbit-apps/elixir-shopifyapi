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
  alias ShopifyAPI.UserTokenServer

  def init(opts), do: opts

  def call(conn, _options) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, app} <- JWTSessionToken.app(token),
         {true, jwt, _jws} <- JWTSessionToken.verify(token, app.client_secret),
         {:ok, myshopify_domain} <- JWTSessionToken.myshopify_domain(jwt),
         {:ok, user_id} <- JWTSessionToken.user_id(jwt),
         {:ok, shop} <- ShopServer.get(myshopify_domain),
         {:ok, auth_token} <- AuthTokenServer.get(myshopify_domain, app.name),
         :ok <- force_reauth(conn, jwt),
         {:ok, user_token} <- JWTSessionToken.get_user_token(jwt, token) do
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

  defp force_reauth(%{params: %{"force_reauth" => "true"}}, jwt),
    do: jwt |> JWTSessionToken.user_id() |> UserTokenServer.delete()

  defp force_reauth(_, _), do: :ok
end
