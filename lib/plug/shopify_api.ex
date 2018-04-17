defmodule Plug.ShopifyApi do
  alias ShopifyApi.Authentication
  alias ShopifyApi.ShopServer

  def init(opts), do: opts

  def call(conn, _opts) do
    IO.puts("here...")
    IO.inspect(conn)

    case List.last(conn.path_info) do
      "install" ->
        conn
        |> Plug.Conn.put_resp_header("location", Authentication.install_url(ShopServer.get()))
        |> Plug.Conn.resp(unquote(302), "You are being redirected.")
        |> Plug.Conn.halt()

      "authenticated" ->
        IO.puts("authenticated...")

        ShopServer.set(%{
          code: conn.query_params["code"],
          hmac: conn.query_params["hmac"],
          shop: conn.query_params["shop"],
          nonce: conn.query_params["state"],
          timestamp: String.to_integer(conn.query_params["timestamp"])
        })

        Authentication.update_token(ShopServer.get())

        conn
        |> Plug.Conn.resp(200, "Authenticated.")
        |> Plug.Conn.halt()

      _ ->
        conn
        |> Plug.Conn.resp(404, "Not Found.")
        |> Plug.Conn.halt()
    end
  end
end
