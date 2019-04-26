defmodule ShopifyAPI.REST.RequestTest do
  use ExUnit.Case

  alias Plug.Conn

  alias ShopifyAPI.{AuthToken, Shop}

  alias ShopifyAPI.REST.Request

  setup _context do
    bypass = Bypass.open()

    shop = %Shop{domain: "localhost:#{bypass.port}"}

    token = %AuthToken{
      token: "token",
      shop_name: shop.domain
    }

    {:ok, %{shop: shop, auth_token: token, bypass: bypass}}
  end

  describe "all" do
    test "auth headers get added to out going request", %{
      bypass: bypass,
      shop: _shop,
      auth_token: token
    } do
      Bypass.expect_once(bypass, "GET", "/admin/api/#{Request.version()}/example", fn conn ->
        headers = conn.req_headers |> Enum.into(%{})
        assert headers["x-shopify-access-token"] == "token"
        Conn.resp(conn, 200, "{}")
      end)

      assert {:ok, _} = Request.get(token, "example")
    end
  end

  describe "GET" do
    test "returns ok when returned status code is 200", %{
      bypass: bypass,
      shop: _shop,
      auth_token: token
    } do
      Bypass.expect_once(bypass, "GET", "/admin/api/#{Request.version()}/example", fn conn ->
        Conn.resp(conn, 200, "{}")
      end)

      assert {:ok, _} = Request.get(token, "example")
    end
  end

  describe "POST" do
    test "returns ok when returned status code is 201", %{
      bypass: bypass,
      shop: _shop,
      auth_token: token
    } do
      Bypass.expect_once(bypass, "POST", "/admin/api/#{Request.version()}/example", fn conn ->
        Conn.resp(conn, 201, "{}")
      end)

      assert {:ok, _} = Request.post(token, "example", %{})
    end
  end
end
