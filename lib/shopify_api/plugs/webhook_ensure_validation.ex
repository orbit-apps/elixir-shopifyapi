defmodule ShopifyAPI.Plugs.WebhookEnsureValidation do
  require Logger
  import Plug.Conn, only: [send_resp: 3, halt: 1]

  def init(opts), do: opts

  def call(%Plug.Conn{assigns: %{shopify_hmac_validated: true}} = conn, _opts), do: conn

  def call(%Plug.Conn{assigns: %{shopify_hmac_validated: false}} = conn, _opts),
    do: send_failure(conn, "HMAC was invalid")

  def call(conn, _opts), do: send_failure(conn, "HMAC validation did not happen")

  defp send_failure(conn, msg) do
    Logger.error(msg)

    conn
    |> send_resp(200, "Failed HMAC Validation")
    |> halt()
  end
end
