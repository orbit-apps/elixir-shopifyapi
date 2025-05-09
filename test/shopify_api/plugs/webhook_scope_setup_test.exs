defmodule ShopifyAPI.Plugs.WebhookScopeSetupTest do
  use ExUnit.Case, async: true

  import Plug.Test
  import Plug.Conn
  import ShopifyAPI.Factory

  alias ShopifyAPI.{AppServer, ShopServer}
  alias ShopifyAPI.Model
  alias ShopifyAPI.Plugs.WebhookScopeSetup

  setup do
    app = build(:app)
    shop = build(:shop)
    AppServer.set(app)
    ShopServer.set(shop)

    conn =
      :post
      |> conn("/shopify/webhooks/", Jason.encode!(%{"id" => 1234}))
      |> put_req_header("content-type", "application/json")

    [conn: conn, app: app, shop: shop]
  end

  @api_version "2025-04"
  @topic "orders/create"

  describe "call/2 with app name and myshopify domain" do
    test "sets webhook scope on assigns", %{conn: conn, app: app, shop: shop} do
      conn =
        conn
        |> put_req_header("x-shopify-shop-domain", shop.domain)
        |> put_req_header("x-shopify-topic", @topic)
        |> put_req_header("x-shopify-api-version", @api_version)
        |> WebhookScopeSetup.call([])

      %{assigns: %{webhook_scope: %Model.WebhookScope{} = webhook_scope}} = conn
      assert webhook_scope.myshopify_domain == shop.domain
      assert webhook_scope.shop == shop
      assert webhook_scope.app == app
      assert webhook_scope.topic == @topic
      assert webhook_scope.shopify_api_version == @api_version
    end
  end

  describe "call/2 without required inputs" do
    test "without a shop myshopify_domain scope is not set", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-shopify-topic", @topic)
        |> put_req_header("x-shopify-api-version", @api_version)
        |> WebhookScopeSetup.call([])

      refute conn.assigns[:webhook_scope]
    end
  end
end
