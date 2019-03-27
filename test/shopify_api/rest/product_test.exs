defmodule ShopifyAPI.REST.ProductTest do
  use ExUnit.Case

  alias Plug.Conn

  alias ShopifyAPI.{AuthToken, Shop}

  alias ShopifyAPI.REST.Product

  setup _context do
    bypass = Bypass.open()

    token = %AuthToken{
      token: "token",
      shop_name: "localhost:#{bypass.port}"
    }

    shop = %Shop{domain: "localhost:#{bypass.port}"}

    {:ok, %{shop: shop, auth_token: token, bypass: bypass}}
  end

  test "", %{bypass: bypass, shop: _shop, auth_token: token} do
    products = %{
      "products" => [
        %{"product_id" => "_", "title" => "Testing Create Product"}
      ]
    }

    Bypass.expect_once(bypass, "GET", "/admin/products.json", fn conn ->
      {:ok, body} = Jason.encode(products)
      Conn.resp(conn, 200, body)
    end)

    assert {:ok, ^products} = Product.all(token)
  end
end
