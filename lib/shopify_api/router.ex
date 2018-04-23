defmodule ShopifyApi.Router do
  require Logger
  use Plug.Router

  plug(:match)
  plug(:dispatch)

  get "/install" do
    case fetch_shopify_app(conn) do
      {:ok, app} ->
        install_url = ShopifyApi.App.install_url(app, shop_domain(conn))

        conn
        |> Plug.Conn.put_resp_header("location", install_url)
        |> Plug.Conn.resp(unquote(302), "You are being redirected.")
        |> Plug.Conn.halt()

      _ ->
        conn
        |> Plug.Conn.resp(404, "Not Found.")
        |> Plug.Conn.halt()
    end
  end

  get "/authorized/:app" do
    Logger.info("Authorized #{shop_domain(conn)}")

    # TODO verify
    # conn.query_params["hmac"],
    # conn.query_params["state"],

    with {:ok, app} <- fetch_shopify_app(conn),
         {:ok, token} <- ShopifyApi.App.fetch_token(app, shop_domain(conn), auth_code(conn)) do
      ShopifyApi.AuthTokenServer.set(shop_domain(conn), app_name(conn), %{
        code: auth_code(conn),
        timestamp: String.to_integer(conn.query_params["timestamp"]),
        token: token,
        shop: shop_domain(conn)
      })

      conn
      |> Plug.Conn.resp(200, "Authenticated.")
      |> Plug.Conn.halt()
    else
      {_, res} ->
        Logger.info("#{__MODULE__} failed authorized with: #{inspect(res)}")

        conn
        |> Plug.Conn.resp(404, "Not Found.")
        |> Plug.Conn.halt()

      _ ->
        conn
        |> Plug.Conn.resp(404, "Not Found.")
        |> Plug.Conn.halt()
    end
  end

  defp fetch_shopify_app(conn) do
    conn
    |> app_name()
    |> ShopifyApi.AppServer.get()
  end

  defp app_name(conn) do
    conn.params["app"]
  end

  defp shop_domain(conn) do
    conn.params["shop"]
  end

  defp auth_code(conn) do
    conn.params["code"]
  end
end
