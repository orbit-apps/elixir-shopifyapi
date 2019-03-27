defmodule ShopifyAPI.Plugs.AdminAuthenticator do
  @moduledoc """
  The ShopifyAPI.Plugs.AdminAuthenticator plug allows for easy admin authentication. The plug when included
  in your route will verify Shopify signatures, that are added to the iframe call on admin page load, and
  set a session cookie for the duration of the session.

  Make sure to include the App name in the path, in our example it is included directly in the path `"/shop-admin/:app"`.

  ## Example Usage
  ```elixir
  # Router
  pipeline :shop_admin do
    plug ShopifyAPI.Plugs.AdminAuthenticator
  end

  scope "/shop-admin/:app", YourAppWeb do
    pipe_through :browser
    pipe_through :shop_admin
    get "/", SomeAdminController, :index
  end
  ```
  """
  import Plug.Conn
  require Logger

  alias Plug.Conn

  alias ShopifyAPI.AppServer
  alias ShopifyAPI.AuthTokenServer
  alias ShopifyAPI.ConnHelpers
  alias ShopifyAPI.Security
  alias ShopifyAPI.ShopServer

  @shopify_api_admin_authenticated :shopify_api_admin_authenticated

  def init(opts), do: opts

  def call(conn, options) do
    if get_sesion(conn, @shopify_api_admin_authenticated) do
      conn
    else
      with {:ok, app} <- ConnHelpers.fetch_shopify_app(conn),
           true <- ConnHelpers.verify_params_with_hmac(app, conn.query_params) do
        conn
        |> ConnHelpers.assign_app()
        |> ConnHelpers.assign_shop()
        |> ConnHelpers.assign_auth_token()
        |> put_session(conn, @shopify_api_admin_authenticated, true)
      else
        res ->
          Logger.info("#{__MODULE__} failed authorized with: #{inspect(res)}")

          conn
          |> delete_session(conn, @shopify_api_admin_authenticated)
          |> Conn.resp(401, "Not Authorized.")
          |> Conn.halt()
      end
    end
  end
end
