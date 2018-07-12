defmodule ShopifyAPI.Plugs.Webhook do
  import Plug.Conn
  require Logger
  alias Plug.Conn
  alias ShopifyAPI.{AppServer, ShopServer, Security}
  alias ShopifyAPI.EventPipe.Event

  def init(opts), do: opts

  def call(conn, options) do
    mount = Keyword.get(options, :mount)

    if String.starts_with?(conn.request_path, mount) do
      conn =
        conn
        |> fetch_shop
        |> fetch_app
        |> fetch_event

      case verify_and_parse(conn) do
        {:ok, conn} ->
          {module, function, _} = Application.get_env(:shopify_api, :webhook_filter)
          apply(module, function, [generate_event(conn)])

          conn
          |> Conn.resp(200, "ok.")
          |> Conn.halt()

        _ ->
          conn
      end
    else
      conn
    end
  end

  defp generate_event(conn) do
    %Event{
      destination: :client,
      app: conn.assigns.app,
      shop: conn.assigns.shop,
      action: conn.assigns.shopify_event,
      object: conn.body_params
    }
  end

  defp fetch_event(conn) do
    with list_of_topics <- Conn.get_req_header(conn, "x-shopify-topic"),
         topic <- List.first(list_of_topics) do
      Conn.assign(conn, :shopify_event, topic)
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

      _ ->
        conn
    end
  end

  defp fetch_app_name(conn) do
    List.last(conn.path_info)
  end

  defp fetch_app(conn) do
    case AppServer.get(fetch_app_name(conn)) do
      {:ok, app} ->
        Conn.assign(conn, :app, app)

      _ ->
        conn
    end
  end

  defp verify_and_parse(conn) do
    with %{client_secret: secret} <- conn.assigns.app,
         {:ok, content, conn} <- read_body(conn),
         signature <- List.first(get_req_header(conn, "x-shopify-hmac-sha256")),
         _ <-
           Logger.info(fn ->
             "#{__MODULE__} actual body hmac is: #{
               inspect(Security.base64_sha256_hmac(content, secret))
             }"
           end),
         ^signature <- Security.base64_sha256_hmac(content, secret),
         {:ok, params} <- Poison.decode(content) do
      {:ok, Map.put(conn, :body_params, params)}
    else
      _ ->
        {:error,
         conn
         |> put_resp_content_type("text/plain")
         |> send_resp(401, "Not Authorized")
         |> halt}
    end
  end
end
