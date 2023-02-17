defmodule ShopifyAPI.Plugs.AdminAuthenticator do
  @moduledoc """
  The ShopifyAPI.Plugs.AdminAuthenticator plug allows for easy admin authentication. The plug
  when included in your route will verify Shopify signatures, that are added to the iframe call
  on admin page load, and set a session cookie for the duration of the session.

  The plug will assign the Shop, App and AuthToken to the Conn for easy access in your
  admin controller.

  Make sure to include the App name in the path, in our example it is included directly in the
  path `"/shop-admin/:app"`.

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
  alias Plug.Conn
  require Logger

  @shopify_shop_header "x-shopify-shop-domain"
  @defaults [shopify_mount_path: "/shop"]

  def init(opts), do: Keyword.merge(opts, @defaults)

  def call(conn, options) do
    with app_name <- conn.params["app"] || List.last(conn.path_info),
         {:ok, app} <- ShopifyAPI.AppServer.get(app_name),
         true <- valid_hmac?(app, conn.query_params),
         myshopify_domain <- shop_domain_from_conn(conn),
         {:ok, shop} <- ShopifyAPI.ShopServer.get(myshopify_domain),
         {:ok, auth_token} <- ShopifyAPI.AuthTokenServer.get(myshopify_domain, app_name) do
      conn
      |> assign_app(app)
      |> assign_shop(shop)
      |> assign_auth_token(auth_token)
    else
      false ->
        Logger.info("#{__MODULE__} failed hmac validation")

        conn
        |> Conn.resp(401, "Not Authorized.")
        |> Conn.halt()

      # Try redirecting to the install path
      _ ->
        conn
        |> Conn.resp(:found, "")
        |> Conn.put_resp_header("location", install_path(options, conn))
        |> Conn.halt()
    end
  end

  defp assign_app(conn, app), do: Conn.assign(conn, :app, app)
  defp assign_shop(conn, shop), do: Conn.assign(conn, :shop, shop)
  defp assign_auth_token(conn, auth_token), do: Conn.assign(conn, :auth_token, auth_token)

  defp shop_domain_from_conn(conn), do: shop_domain_from_header(conn) || conn.params["shop"]

  defp shop_domain_from_header(conn),
    do: conn |> Conn.get_req_header(@shopify_shop_header) |> List.first()

  defp valid_hmac?(%ShopifyAPI.App{client_secret: secret}, params) do
    params["hmac"] ==
      params
      |> Enum.reject(fn {key, _} -> key == "hmac" or key == "signature" end)
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map_join("&", fn {key, value} -> key <> "=" <> value end)
      |> ShopifyAPI.Security.base16_sha256_hmac(secret)
  end

  defp install_path(options, conn) do
    app_name = conn.params["app"] || List.last(conn.path_info)

    options[:shopify_mount_path] <>
      "/install" <>
      "?app=" <>
      app_name <>
      "&shop=" <>
      shop_domain_from_conn(conn)
  end
end
