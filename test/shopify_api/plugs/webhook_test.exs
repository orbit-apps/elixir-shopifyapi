defmodule ShopifyAPI.Plugs.WebhookTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias ShopifyAPI.{App, AppServer, Shop, ShopServer}
  alias ShopifyAPI.Plugs.Webhook

  @secret "new_secret"

  @app %App{name: "testapp", client_secret: @secret}
  @shop %Shop{domain: "test-shop.example.com"}

  setup do
    AppServer.set(@app)
    ShopServer.set(@shop)

    Process.register(self(), :webhook_plug_test)

    :ok
  end

  defmodule MockExecutor do
    def call(app, shop, topic, payload) do
      send(:webhook_plug_test, {:webhook, app, shop, topic, payload})
      :ok
    end
  end

  defmodule BadExecutor do
    def call(_app, _shop, _topic, _payload) do
      raise "something went wrong!"
    end
  end

  @opts Webhook.init(prefix: "/shopify/webhooks/", callback: {MockExecutor, :call, []})

  test "ignores non-webhook requests" do
    ignorables = [
      conn(:get, "/", []),
      conn(:post, "/shopify", []),
      conn(:get, "/shopify/webhooks", []),
      conn(:get, "/shopify/webhooks/abcd", [])
    ]

    for req <- ignorables do
      conn = Webhook.call(req, @opts)
      assert conn.status == nil
      refute conn.halted
    end
  end

  test "dispatches verified webhook requests to the configured callback" do
    payload = %{"id" => 1234}
    {hmac, json_payload} = encode_with_hmac(payload)

    conn =
      :post
      |> conn("/shopify/webhooks/testapp", json_payload)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-shopify-shop-domain", "test-shop.example.com")
      |> put_req_header("x-shopify-topic", "orders/create")
      |> put_req_header("x-shopify-hmac-sha256", hmac)
      |> Webhook.call(@opts)

    assert_received {:webhook, @app, @shop, "orders/create", ^payload}

    assert conn.halted
    assert conn.status == 200
    assert conn.resp_body == "ok"
  end

  test "dispatches manditory webhook requests to the configured callback" do
    payload = %{"id" => 1234}
    {hmac, json_payload} = encode_with_hmac(payload)

    conn =
      :post
      |> conn("/shopify/webhooks/testapp", json_payload)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-shopify-topic", "shop/redact")
      |> put_req_header("x-shopify-hmac-sha256", hmac)
      |> Webhook.call(@opts)

    assert_received {:webhook, @app, nil, "shop/redact", ^payload}

    assert conn.halted
    assert conn.status == 200
    assert conn.resp_body == "ok"
  end

  test "responds with a 401 if the payload cannot be verified" do
    payload = %{"id" => 1234}
    {hmac, json_payload} = encode_with_hmac(payload)

    req =
      :post
      |> conn("/shopify/webhooks/testapp", json_payload)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-shopify-shop-domain", "test-shop.example.com")
      |> put_req_header("x-shopify-topic", "orders/create")
      |> put_req_header("x-shopify-hmac-sha256", hmac <> "nope")

    conn = Webhook.call(req, @opts)

    assert conn.halted
    assert conn.status == 401
    assert conn.resp_body == "unauthorized"
    refute_received {:webhook, _, _, _}
  end

  test "responds with an error if the handler returns an error" do
    opts =
      Webhook.init(
        prefix: "/shopify/webhooks/",
        callback: {BadExecutor, :call, []}
      )

    payload = %{"id" => 1234}
    {hmac, json_payload} = encode_with_hmac(payload)

    req =
      :post
      |> conn("/shopify/webhooks/testapp", json_payload)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-shopify-shop-domain", "test-shop.example.com")
      |> put_req_header("x-shopify-topic", "orders/create")
      |> put_req_header("x-shopify-hmac-sha256", hmac)

    conn = Webhook.call(req, opts)

    assert conn.halted
    assert conn.status == 500
    assert conn.resp_body == "internal server error"
  end

  test "responds with an error if the app is not registered" do
    payload = %{"id" => 1234}
    {hmac, json_payload} = encode_with_hmac(payload)

    req =
      :post
      |> conn("/shopify/webhooks/unknown-app", json_payload)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-shopify-shop-domain", "test-shop.example.com")
      |> put_req_header("x-shopify-topic", "orders/create")
      |> put_req_header("x-shopify-hmac-sha256", hmac <> "nope")

    conn = Webhook.call(req, @opts)

    assert conn.halted
    assert conn.status == 401
    assert conn.resp_body == "unauthorized"
    refute_received {:webhook, _, _, _}
  end

  # Encodes an object as JSON, generating a HMAC string for integrity verification.
  # Returns a two-tuple containing the Base64-encoded HMAC and JSON payload string.
  if System.otp_release() >= "22" do
    defp encode_with_hmac(payload) when is_map(payload) do
      json_payload = Jason.encode!(payload)
      hmac = Base.encode64(:crypto.mac(:hmac, :sha256, @secret, json_payload))
      {hmac, json_payload}
    end
  else
    defp encode_with_hmac(payload) when is_map(payload) do
      json_payload = Jason.encode!(payload)
      hmac = Base.encode64(:crypto.hmac(:sha256, @secret, json_payload))
      {hmac, json_payload}
    end
  end
end
