defmodule ShopifyApi.WebhookRouterTest do
  use ExUnit.Case
  use Plug.Test

  def parse(conn, opts \\ []) do
    opts = Keyword.put_new(opts, :parsers, [Plug.Parsers.URLENCODED, Plug.Parsers.MULTIPART])
    Plug.Parsers.call(conn, Plug.Parsers.init(opts))
  end

  @app_name "test"
  @shop_domain "shop.example.com"
  @shopify_topic "test"

  setup do
    ShopifyApi.AppServer.set(@app_name, %{
      name: @app_name
    })

    ShopifyApi.ShopServer.set(%{domain: @shop_domain})
  end

  describe "with App and Store" do
    setup do
      conn =
        conn(:post, "/" <> @app_name)
        |> Plug.Conn.put_req_header("x-shopify-shop-domain", @shop_domain)
        |> Plug.Conn.put_req_header("x-shopify-topic", @shopify_topic)
        |> parse

      conn = call(ShopifyApi.WebhookRouter, conn)

      %{conn: conn}
    end

    test "it returns 200", %{conn: conn} do
      assert conn.status == 200
    end

    test "sets the App on the conn", %{conn: conn} do
      assert conn.assigns[:app].name == @app_name
    end

    test "sets the Shop on the conn", %{conn: conn} do
      assert conn.assigns[:shop].domain == @shop_domain
    end

    test "sets the Shopify Event on the conn", %{conn: conn} do
      assert conn.assigns[:shopify_event] == @shopify_topic
    end
  end

  defp call(mod, conn) do
    mod.call(conn, [])
  end
end
