defmodule Plug.ShopifyApi do
  require Logger
  alias ShopifyApi.Authentication
  alias ShopifyApi.ShopServer

  def init(opts), do: opts

  def call(conn, _opts) do
    case List.last(conn.path_info) do
      "install" ->
        case fetch_shop(conn) do
          {:ok, shop} ->
            conn
            |> Plug.Conn.put_resp_header("location", Authentication.install_url(shop))
            |> Plug.Conn.resp(unquote(302), "You are being redirected.")
            |> Plug.Conn.halt()

          _ ->
            conn
            |> Plug.Conn.resp(404, "Not Found.")
            |> Plug.Conn.halt()
        end

      "authenticated" ->
        Logger.info("Authenticated #{conn.query_params["shop"]}")

        ShopServer.set(%{
          code: conn.query_params["code"],
          hmac: conn.query_params["hmac"],
          domain: conn.query_params["shop"],
          nonce: conn.query_params["state"],
          timestamp: String.to_integer(conn.query_params["timestamp"])
        })

        Authentication.update_token(fetch_shop(conn))

        conn
        |> Plug.Conn.resp(200, "Authenticated.")
        |> Plug.Conn.halt()

      _ ->
        conn
        |> Plug.Conn.resp(404, "Not Found.")
        |> Plug.Conn.halt()
    end
  end

  defp fetch_shop(conn) do
    ShopServer.get(conn.query_params["domain"])
  end
end
