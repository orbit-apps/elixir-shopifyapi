defmodule ShopifyAPI.WebhookHMACValidatorTest do
  use ExUnit.Case, async: true

  import Plug.Test
  import Plug.Conn
  import ShopifyAPI.Factory

  alias ShopifyAPI.AppServer
  alias ShopifyAPI.WebhookHMACValidator

  setup do
    app = build(:app)
    AppServer.set(app)

    {hmac, payload} = encode_with_hmac(app, %{"id" => 1234})

    conn =
      :post
      |> conn("/shopify/webhooks/testapp", payload)
      |> put_req_header("content-type", "application/json")

    [conn: conn, app: app, payload: payload, hmac: hmac]
  end

  describe "read_body/2 with required attributes set" do
    test "happy path", %{conn: conn, payload: payload, hmac: hmac} do
      {:ok, body, conn} =
        conn
        |> put_req_header("x-shopify-hmac-sha256", hmac)
        |> WebhookHMACValidator.read_body([])

      assert body == payload
      assert conn.assigns.shopify_hmac_validated
    end

    test "with invalid hmac", %{conn: conn, payload: payload} do
      {:ok, body, conn} =
        conn
        |> put_req_header("x-shopify-hmac-sha256", "invalid")
        |> WebhookHMACValidator.read_body([])

      assert body == payload
      refute conn.assigns.shopify_hmac_validated
    end
  end

  describe "read_body/2 with some missing attributes" do
    test "without the hmac header", %{conn: conn, payload: payload} do
      {:ok, body, conn} = WebhookHMACValidator.read_body(conn, [])
      assert body == payload
      refute conn.assigns[:shopify_hmac_validated]
    end

    test "with an invalid app_name", %{conn: conn, payload: payload, hmac: hmac} do
      {:ok, body, conn} =
        conn
        |> put_req_header("x-shopify-hmac-sha256", hmac)
        |> WebhookHMACValidator.read_body(app_name: "invalid")

      assert body == payload
      refute conn.assigns[:shopify_hmac_validated]
    end
  end

  # Encodes an object as JSON, generating a HMAC string for integrity verification.
  # Returns a two-tuple containing the Base64-encoded HMAC and JSON payload string.
  defp encode_with_hmac(%{client_secret: secret}, payload) do
    json = Jason.encode!(payload)
    hmac = Base.encode64(:crypto.mac(:hmac, :sha256, secret, json))
    {hmac, json}
  end
end
