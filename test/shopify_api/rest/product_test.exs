defmodule ShopifyAPI.REST.ProductTest do
  use ExUnit.Case

  alias Plug.Conn
  alias ShopifyAPI.{AuthToken, JSONSerializer, Shop}
  alias ShopifyAPI.REST.{Product, Request}

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
    product = %{"product_id" => "_", "title" => "Testing Create Product"}

    Bypass.expect_once(bypass, "GET", "/admin/api/#{Request.version()}/products.json", fn conn ->
      {:ok, body} = JSONSerializer.encode(%{products: [product]})

      Conn.resp(conn, 200, body)
    end)

    assert {:ok, [^product]} = Product.all(token)
  end
end
