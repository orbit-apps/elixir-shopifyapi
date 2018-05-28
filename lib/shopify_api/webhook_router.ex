defmodule ShopifyApi.WebhookRouter do
  require Logger
  use Plug.Router

  plug(:match)
  plug(:dispatch)

  @doc """
  POST endpoint for Shopify Webhook calls.

  Shop, App, and the Shopify Event are stored on the connection as:
    - :shop
    - :app
    - :shopify_event
  """
  post "/:app" do
    with conn <- fetch_app(conn),
         {:ok, raw_body, conn} <- read_body(conn),
         conn <- parse_body(conn, raw_body),
         true <- verify_hmac(conn, conn.assigns.app, raw_body),
         conn <- fetch_shop(conn),
         conn <- fetch_app(conn),
         conn <- fetch_event(conn) do
      ShopifyApi.EventPipe.WebhookEventQueue.sync_notify(%ShopifyApi.EventPipe.Event{
        destination: :webhook,
        action: conn.assigns.shopify_event,
        object: conn.body_params
      })

      conn
      |> Plug.Conn.resp(200, "ok.")
      |> Plug.Conn.halt()
    else
      _ ->
        Logger.warn(fn -> "#{__MODULE__} failed validation of webhook callback" end)

        conn
        |> Plug.Conn.resp(200, "ok.")
        |> Plug.Conn.halt()
    end
  end

  defp verify_hmac(conn, %ShopifyApi.App{client_secret: secret}, content) do
    List.first(Plug.Conn.get_req_header(conn, "x-shopify-hmac-sha256")) ==
      ShopifyApi.Security.base64_sha256_hmac(content, secret)
  end

  # TODO support XML
  defp parse_body(conn, content) do
    case Poison.decode(content) do
      {:ok, json} ->
        Map.put(conn, :body_params, json)
    end
  end

  defp fetch_shop_name(conn) do
    conn
    |> Plug.Conn.get_req_header("x-shopify-shop-domain")
    |> List.first()
  end

  defp fetch_shop(conn) do
    case ShopifyApi.ShopServer.get(fetch_shop_name(conn)) do
      {:ok, shop} ->
        Plug.Conn.assign(conn, :shop, shop)
    end
  end

  defp fetch_app(conn) do
    case ShopifyApi.AppServer.get(conn.path_params["app"]) do
      {:ok, app} ->
        Plug.Conn.assign(conn, :app, app)
    end
  end

  defp fetch_event(conn) do
    with list_of_topics <- Plug.Conn.get_req_header(conn, "x-shopify-topic"),
         topic <- List.first(list_of_topics) do
      Plug.Conn.assign(conn, :shopify_event, topic)
    end
  end
end
