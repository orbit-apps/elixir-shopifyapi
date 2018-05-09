defmodule ShopifyApi.Router do
  require Logger
  use Plug.Router

  plug(:match)
  plug(:dispatch)

  if Mix.env() == :dev do
    use Plug.Debugger
  end

  get "/install" do
    case fetch_shopify_app(conn) do
      {:ok, app} ->
        install_url = ShopifyApi.App.install_url(app, shop_domain(conn))

        conn
        |> Plug.Conn.put_resp_header("location", install_url)
        |> Plug.Conn.resp(unquote(302), "You are being redirected.")
        |> Plug.Conn.halt()

      res ->
        Logger.info("#{__MODULE__} failed install with: #{res}")

        conn
        |> Plug.Conn.resp(404, "Not Found.")
        |> Plug.Conn.halt()
    end
  end

  # Shopify Callback on App authorization
  get "/authorized/:app" do
    Logger.info("Authorized #{shop_domain(conn)}")

    with {:ok, app} <- fetch_shopify_app(conn),
         true <- verify_nonce(app, conn.query_params),
         true <- verify_hmac(app, conn.query_params),
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
      res ->
        Logger.info("#{__MODULE__} failed authorized with: #{inspect(res)}")

        conn
        |> Plug.Conn.resp(404, "Not Found.")
        |> Plug.Conn.halt()
    end
  end

  forward("/webhook", to: ShopifyApi.WebhookRouter)

  # TODO this should be behind a api token authorization
  forward("/graphql/config", to: Absinthe.Plug, schema: GraphQL.Config.Schema)

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

  defp verify_nonce(%ShopifyApi.App{nonce: nonce}, params) do
    nonce == params["state"]
  end

  defp verify_hmac(%ShopifyApi.App{client_secret: secret}, params) do
    params["hmac"] ==
      params
      |> Enum.reject(fn x -> elem(x, 0) == "hmac" end)
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map_every(1, &(elem(&1, 0) <> "=" <> elem(&1, 1)))
      |> Enum.map_join("&", & &1)
      |> ShopifyApi.Security.sha256_hmac(secret)
  end
end