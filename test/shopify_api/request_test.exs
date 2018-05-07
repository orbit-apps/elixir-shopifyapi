defmodule ShopifyApi.RequestTest do
  use ExUnit.Case
  alias ShopifyApi.Request

  setup _context do
    bypass = Bypass.open()

    shop = %ShopifyApi.Shop{domain: "localhost:#{bypass.port}"}

    token = %ShopifyApi.AuthToken{
      token: "token",
      shop_name: shop.domain
    }

    {:ok, %{shop: shop, auth_token: token, bypass: bypass}}
  end

  describe "all" do
    test "auth headers get added to out going request", %{
      bypass: bypass,
      shop: shop,
      auth_token: token
    } do
      Bypass.expect_once(bypass, "GET", "/admin/example", fn conn ->
        headers = conn.req_headers |> Enum.into(%{})
        assert headers["x-shopify-access-token"] == "token"
        Plug.Conn.resp(conn, 200, "{}")
      end)

      assert {:ok, _} = Request.get(token, "example")
    end
  end

  describe "GET" do
    test "returns ok when returned status code is 200", %{
      bypass: bypass,
      shop: shop,
      auth_token: token
    } do
      Bypass.expect_once(bypass, "GET", "/admin/example", fn conn ->
        Plug.Conn.resp(conn, 200, "{}")
      end)

      assert {:ok, _} = Request.get(token, "example")
    end
  end

  describe "POST" do
    test "returns ok when returned status code is 201", %{
      bypass: bypass,
      shop: shop,
      auth_token: token
    } do
      Bypass.expect_once(bypass, "POST", "/admin/example", fn conn ->
        Plug.Conn.resp(conn, 201, "{}")
      end)

      assert {:ok, _} = Request.post(token, "example", %{})
    end

    test "3/Arity is a default map", %{
      bypass: bypass,
      shop: shop,
      auth_token: token
    } do
      Bypass.expect_once(bypass, "POST", "/admin/example", fn conn ->
        IO.inspect(conn)
        # assert Plug.Conn.body_params(conn) = %{foo: "bar"}
        Plug.Conn.resp(conn, 201, "{}")

        # TODO: Add use parse example to check that shape is expected.
      end)

      assert {:ok, _} = Request.post(token, "example", %{foo: "bar"})
    end
  end
end
