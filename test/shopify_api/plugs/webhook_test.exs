defmodule ShopifyAPI.Plugs.WebhookTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Plug.Conn
  alias ShopifyAPI.Plugs.Webhook
  alias ShopifyAPI.{App, AppServer, Shop, ShopServer}

  @app %App{name: "test"}
  @shop %Shop{domain: "test-shop.example.com"}
  @req_body %{app: @app.name, shop: @shop.domain}

  def webhook_callback(v) do
    send(self(), {:webhook_callback, v})
  end

  setup do
    ShopServer.set(@shop)
    AppServer.set(@app)
  end

  test "401s with invalid hmac" do
    # Create a test connection
    params = %{app: @app.name, shop: @shop.domain}

    conn =
      :post
      |> conn("/webhook", params)
      |> Conn.put_req_header("x-shopify-hmac-sha256", "invalid")

    # Invoke the plug
    conn = Webhook.call(conn, mount: "/webhook")

    # Assert the response and status
    assert conn.state == :sent
    assert conn.status == 401
    assert conn.resp_body == "Not Authorized"
  end

  test "fires callback and 200s with valid hmac" do
    Application.put_env(:shopify_api, :webhook_filter, {__MODULE__, :webhook_callback, []})
    # Create a test connection
    conn =
      :post
      |> conn("/webhook/#{@app.name}?", Poison.encode!(@req_body))
      |> Conn.fetch_query_params()
      |> Conn.put_req_header(
        "x-shopify-hmac-sha256",
        "ezEuMM4V7mm7fWuNyMXARfODfP5gnyHLyVk9bW2cye4="
      )
      |> Conn.put_req_header("x-shopify-shop-domain", @shop.domain)

    # Invoke the plug
    conn = Webhook.call(conn, mount: "/webhook")

    # Assert the response and status
    assert conn.state == :sent
    assert conn.status == 200
    assert conn.resp_body == "ok."

    expected_event = %ShopifyAPI.EventPipe.Event{
      action: nil,
      app: @app,
      assigns: %{},
      callback: nil,
      destination: :client,
      object: %{"app" => @app.name, "shop" => @shop.domain},
      shop: @shop,
      token: %{}
    }

    assert_receive({:webhook_callback, ^expected_event})
  end
end