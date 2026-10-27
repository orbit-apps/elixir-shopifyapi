defmodule ShopifyAPI.Plugs.WebhookTest do
  use ExUnit.Case, async: true

  import Plug.Test
  import Plug.Conn
  import ShopifyAPI.Factory

  alias ShopifyAPI.{AppServer, ShopServer}
  alias ShopifyAPI.Plugs.Webhook

  @secret ShopifyAPI.Factory.shopify_app_secret()

  setup do
    app = build(:app)
    shop = build(:shop)
    AppServer.set(app)
    ShopServer.set(shop)

    Process.register(self(), :webhook_plug_test)

    [app: app, shop: shop]
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

  test "dispatches verified webhook requests to the configured callback", %{app: app, shop: shop} do
    payload = %{"id" => 1234}
    {hmac, json_payload} = encode_with_hmac(payload)

    conn =
      :post
      |> conn("/shopify/webhooks/testapp", json_payload)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-shopify-shop-domain", shop.domain)
      |> put_req_header("x-shopify-topic", "orders/create")
      |> put_req_header("x-shopify-hmac-sha256", hmac)
      |> Webhook.call(@opts)

    assert_received {:webhook, ^app, ^shop, "orders/create", ^payload}

    assert conn.halted
    assert conn.status == 200
    assert conn.resp_body == "ok"
  end

  test "dispatches manditory webhook requests to the configured callback", %{app: app} do
    payload = %{"id" => 1234}
    {hmac, json_payload} = encode_with_hmac(payload)

    conn =
      :post
      |> conn("/shopify/webhooks/testapp", json_payload)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-shopify-topic", "shop/redact")
      |> put_req_header("x-shopify-hmac-sha256", hmac)
      |> Webhook.call(@opts)

    assert_received {:webhook, ^app, nil, "shop/redact", ^payload}

    assert conn.halted
    assert conn.status == 200
    assert conn.resp_body == "ok"
  end

  test "responds with a 401 if the payload cannot be verified", %{shop: shop} do
    payload = %{"id" => 1234}
    {hmac, json_payload} = encode_with_hmac(payload)

    req =
      :post
      |> conn("/shopify/webhooks/testapp", json_payload)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-shopify-shop-domain", shop.domain)
      |> put_req_header("x-shopify-topic", "orders/create")
      |> put_req_header("x-shopify-hmac-sha256", hmac <> "nope")

    conn = Webhook.call(req, @opts)

    assert conn.halted
    assert conn.status == 401
    assert conn.resp_body == "unauthorized"
    refute_received {:webhook, _, _, _}
  end

  test "responds with an error if the handler returns an error", %{shop: shop} do
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
      |> put_req_header("x-shopify-shop-domain", shop.domain)
      |> put_req_header("x-shopify-topic", "orders/create")
      |> put_req_header("x-shopify-hmac-sha256", hmac)

    conn = Webhook.call(req, opts)

    assert conn.halted
    assert conn.status == 500
    assert conn.resp_body == "internal server error"
  end

  test "responds with an error if the app is not registered", %{shop: shop} do
    payload = %{"id" => 1234}
    {hmac, json_payload} = encode_with_hmac(payload)

    req =
      :post
      |> conn("/shopify/webhooks/unknown-app", json_payload)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-shopify-shop-domain", shop.domain)
      |> put_req_header("x-shopify-topic", "orders/create")
      |> put_req_header("x-shopify-hmac-sha256", hmac <> "nope")

    conn = Webhook.call(req, @opts)

    assert conn.halted
    assert conn.status == 401
    assert conn.resp_body == "unauthorized"
    refute_received {:webhook, _, _, _}
  end

  test "dispatches a webhook signed with the app's secondary secret" do
    app = %{
      build(:app)
      | name: "rotating-app",
        client_id: "rotating-app-id",
        client_secret_secondary: "old_secret"
    }

    AppServer.set(app)

    conn = post_webhook("/shopify/webhooks/rotating-app", %{"id" => 1}, "old_secret")

    assert conn.status == 200
    assert_received {:webhook, ^app, _shop, "orders/create", %{"id" => 1}}
  end

  defp post_webhook(path, payload, secret) do
    {hmac, json_payload} = encode_with_hmac(payload, secret)

    :post
    |> conn(path, json_payload)
    |> put_req_header("content-type", "application/json")
    |> put_req_header("x-shopify-topic", "orders/create")
    |> put_req_header("x-shopify-hmac-sha256", hmac)
    |> Webhook.call(@opts)
  end

  # Encodes an object as JSON, generating a HMAC string for integrity verification.
  # Returns a two-tuple containing the Base64-encoded HMAC and JSON payload string.
  defp encode_with_hmac(payload, secret \\ @secret) when is_map(payload) do
    json_payload = Jason.encode!(payload)
    {ShopifyAPI.Security.base64_sha256_hmac(json_payload, secret), json_payload}
  end
end
