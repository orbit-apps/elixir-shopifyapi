defmodule ShopifyAPI.Plugs.AdminAuthenticator do
  @moduledoc """
  The ShopifyAPI.Plugs.AdminAuthenticator plug allows for easy admin authentication. The plug when included
  in your route will verify Shopify signatures, that are added to the iframe call on admin page load, and
  set a session cookie for the duration of the session.

  The plug will assign the Shop, App and AuthToken to the Conn for easy access in your admin controller.

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
  import ShopifyAPI.ConnHelpers
  require Logger

  @session_key :shopify_api_admin_authenticated
  @defaults [shopify_mount_path: "/shop"]

  def init(opts), do: Keyword.merge(opts, @defaults)

  def call(conn, options) do
    if get_session(conn, @session_key) do
      # rehydrate the conn.assigns for the app, shop and auth token.
      conn
      |> assign_app(get_session(conn, :app_name))
      |> assign_shop(get_session(conn, :shop_name))
      |> assign_auth_token()
    else
      do_authentication(conn, options)
    end
  end

  defp do_authentication(conn, options) do
    with {:ok, app} <- fetch_shopify_app(conn),
         true <- verify_params_with_hmac(app, conn.query_params) do
      # store the App and Shop name in the session for use on other page views
      conn
      |> assign_app(app)
      |> assign_shop()
      |> assign_auth_token()
      |> put_session(:app_name, app_name(conn))
      |> put_session(:shop_domain, shop_domain(conn))
      |> put_session(@session_key, true)
    else
      false ->
        Logger.info("#{__MODULE__} failed hmac validation")

        conn
        |> delete_session(@session_key)
        |> resp(401, "Not Authorized.")
        |> halt()

      :error ->
        install_url =
          options[:shopify_mount_path] <> "/install?app=up_sell&shop=" <> shop_domain(conn)

        conn
        |> resp(:found, "")
        |> put_resp_header("location", install_url)
        |> halt()
    end
  end
end
