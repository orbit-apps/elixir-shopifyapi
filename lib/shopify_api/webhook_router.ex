defmodule ShopifyApi.WebhookRouter do
  require Logger
  use Plug.Router

  alias Plug.Conn
  alias ShopifyApi.EventPipe.{Event, WebhookEventQueue}
  alias ShopifyApi.{App, AppServer, ShopServer, Security}

  plug(:match)
  plug(:dispatch)

  # POST endpoint for Shopify Webhook calls.
  #
  # Shop, App, and the Shopify Event are stored on the connection as:
  #   - :shop
  #   - :app
  #   - :shopify_event
  post "/:app" do
    with conn <- fetch_app(conn),
         {:ok, raw_body, conn} <- read_body(conn),
         conn <- parse_body(conn, raw_body),
         true <- verify_hmac(conn, conn.assigns.app, raw_body),
         conn <- fetch_shop(conn),
         conn <- fetch_app(conn),
         conn <- fetch_event(conn) do
      WebhookEventQueue.sync_notify(%Event{
        destination: :webhook,
        action: conn.assigns.shopify_event,
        object: conn.body_params
      })

      conn
      |> Conn.resp(200, "ok.")
      |> Conn.halt()
    else
      _ ->
        Logger.warn(fn -> "#{__MODULE__} failed validation of webhook callback" end)

        conn
        |> Conn.resp(200, "ok.")
        |> Conn.halt()
    end
  end

  defp verify_hmac(conn, %App{client_secret: secret}, content) do
    List.first(Conn.get_req_header(conn, "x-shopify-hmac-sha256")) ==
      Security.base64_sha256_hmac(content, secret)
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
    |> Conn.get_req_header("x-shopify-shop-domain")
    |> List.first()
  end

  defp fetch_shop(conn) do
    case ShopServer.get(fetch_shop_name(conn)) do
      {:ok, shop} ->
        Conn.assign(conn, :shop, shop)
    end
  end

  defp fetch_app(conn) do
    case AppServer.get(conn.path_params["app"]) do
      {:ok, app} ->
        Conn.assign(conn, :app, app)
    end
  end

  defp fetch_event(conn) do
    with list_of_topics <- Conn.get_req_header(conn, "x-shopify-topic"),
         topic <- List.first(list_of_topics) do
      Conn.assign(conn, :shopify_event, topic)
    end
  end
end
