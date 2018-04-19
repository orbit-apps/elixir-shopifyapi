defmodule ShopifyApi.ProductTest do
  use ExUnit.Case
  alias ShopifyApi.Product

  setup _context do
    bypass = Bypass.open()

    token = %ShopifyApi.AuthToken{
      token: "token",
      shop: "localhost:#{bypass.port}"
    }
    shop = %ShopifyApi.Shop{domain: "localhost:#{bypass.port}"}

    {:ok, %{shop: shop, auth_token: token, bypass: bypass}}
  end

  test "", %{bypass: bypass, shop: shop, auth_token: token} do
    products = %{
      "products" => [
        %{"product_id" => "_", "title" => "Testing Create Product"}
      ]
    }

    Bypass.expect_once(bypass, "GET", "/admin/products.json", fn conn ->
      {:ok, body} = Poison.encode(products)
      Plug.Conn.resp(conn, 200, body)
    end)

    assert {:ok, products} = Product.all(token)
  end
end
