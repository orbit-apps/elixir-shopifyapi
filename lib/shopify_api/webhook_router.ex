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
    conn =
      conn
      |> fetch_shop
      |> fetch_app
      |> fetch_event

    Logger.debug("#{__MODULE__} #{conn.assigns[:shop].domain}")

    # TODO Webhooks need to actually store this message somewhere that it can be picked up and processed

    conn
    |> Plug.Conn.resp(200, "ok.")
    |> Plug.Conn.halt()
  end

  defp fetch_shop_name(conn) do
    conn
    |> Plug.Conn.get_req_header("x-shopify-shop-domain")
    |> List.first()
  end

  defp fetch_app_name(conn) do
    conn.path_params["app"]
  end

  defp fetch_shop(conn) do
    case ShopifyApi.ShopServer.get(fetch_shop_name(conn)) do
      {:ok, shop} ->
        Plug.Conn.assign(conn, :shop, shop)
    end
  end

  defp fetch_app(conn) do
    case ShopifyApi.AppServer.get(fetch_app_name(conn)) do
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
