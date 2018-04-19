defmodule ShopifyApi.ProductTest do
  use ExUnit.Case
  alias ShopifyApi.Product

  setup _context do
    bypass = Bypass.open()

    shop = %ShopifyApi.Shop{
      access_token: "token",
      client_id: "id",
      client_secret: "secret",
      domain: "localhost:#{bypass.port}",
      auth_redirect_uri: "http://shop.example.com/shop/authorized",
      nonce: "test"
    }

    {:ok, %{shop: shop, bypass: bypass}}
  end

  test "", %{bypass: bypass, shop: shop} do
    products = %{
      "products" => [
        %{"product_id" => "_", "title" => "Testing Create Product"}
      ]
    }

    Bypass.expect_once(bypass, "GET", "/admin/products.json", fn conn ->
      {:ok, body} = Poison.encode(products)
      Plug.Conn.resp(conn, 200, body)
    end)

    assert {:ok, products} = Product.all(shop)
  end
end
