defmodule ShopifyAPI.WebhookHMACValidator do
  @moduledoc """
  A custom body reader to handle authenticating incoming webhooks from Shopify.

  This plug reads the body and verifies the HMAC if the header is present setting a
  `shopify_hmac_validated` on the conn's assigns.

  ## Usage

  Add the following configuration to your endpoint.ex for the Plug.Parser config.
  `body_reader: {ShopifyAPI.WebhookHMACValidator, :read_body, []},`

  Should now look something like:
  ```elixir
  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    body_reader: {ShopifyAPI.WebhookHMACValidator, :read_body, []},
    json_decoder: Phoenix.json_library()
  ```

  ## Options

  - app_name: optional, the name of the app for look up in the AppServer if left blank
    it will use the Application Config or the last element of the request path.
  """
  require Logger
  import Plug.Conn, only: [assign: 3, get_req_header: 2]

  @shopify_hmac_header "x-shopify-hmac-sha256"

  def read_body(conn, opts) do
    with {:ok, body, conn} <- Plug.Conn.read_body(conn, opts) do
      conn = assign_hmac_validation(conn, body, opts)
      {:ok, body, conn}
    end
  end

  def assign_hmac_validation(conn, body, opts) do
    with shopify_hmac when is_binary(shopify_hmac) <- get_header(conn, @shopify_hmac_header),
         app_name when is_binary(app_name) <- ShopifyAPI.Config.app_name(conn, opts),
         {:ok, %ShopifyAPI.App{client_secret: client_secret}} <-
           ShopifyAPI.AppServer.get(app_name) do
      payload_hmac = ShopifyAPI.Security.base64_sha256_hmac(body, client_secret)

      assign(
        conn,
        :shopify_hmac_validated,
        Plug.Crypto.secure_compare(shopify_hmac, payload_hmac)
      )
    else
      _ -> conn
    end
  end

  defp get_header(conn, key), do: conn |> get_req_header(key) |> List.first()
end
