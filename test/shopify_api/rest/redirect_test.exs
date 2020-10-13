defmodule ShopifyAPI.REST.RedirectTest do
  use ExUnit.Case

  alias Plug.Conn
  alias ShopifyAPI.{AuthToken, JSONSerializer, Shop}
  alias ShopifyAPI.REST.{Redirect, Request}

  setup _context do
    bypass = Bypass.open()

    token = %AuthToken{
      token: "token",
      shop_name: "localhost:#{bypass.port}"
    }

    shop = %Shop{domain: "localhost:#{bypass.port}"}

    redirect = %{
      "id" => 979_034_144,
      "path" => "/ipod",
      "target" => "/pages/itunes"
    }

    {:ok, %{shop: shop, auth_token: token, bypass: bypass, redirect: redirect}}
  end

  test "client can request all redirects", %{
    bypass: bypass,
    shop: _shop,
    auth_token: token,
    redirect: redirect
  } do
    Bypass.expect_once(bypass, "GET", "/admin/api/#{Request.version()}/redirects.json", fn conn ->
      {:ok, body} = JSONSerializer.encode(%{redirects: [redirect]})

      Conn.resp(conn, 200, body)
    end)

    assert {:ok, [redirect]} == Redirect.all(token)
  end

  test "client can request a single redirect", %{
    bypass: bypass,
    shop: _shop,
    auth_token: token,
    redirect: redirect
  } do
    Bypass.expect_once(
      bypass,
      "GET",
      "/admin/api/#{Request.version()}/redirects/#{redirect["id"]}.json",
      fn conn ->
        {:ok, body} = JSONSerializer.encode(%{redirect: redirect})

        Conn.resp(conn, 200, body)
      end
    )

    assert {:ok, redirect} == Redirect.get(token, redirect["id"])
  end

  test "client can request a redirect count", %{
    bypass: bypass,
    shop: _shop,
    auth_token: token,
    redirect: _redirect
  } do
    count = 1234

    Bypass.expect_once(
      bypass,
      "GET",
      "/admin/api/#{Request.version()}/redirects/count.json",
      fn conn ->
        {:ok, body} = JSONSerializer.encode(%{redirects: count})

        Conn.resp(conn, 200, body)
      end
    )

    assert {:ok, count} == Redirect.count(token)
  end

  test "client can request to create a redirect", %{
    bypass: bypass,
    shop: _shop,
    auth_token: token,
    redirect: redirect
  } do
    Bypass.expect_once(
      bypass,
      "POST",
      "/admin/api/#{Request.version()}/redirects.json",
      fn conn ->
        {:ok, body} = JSONSerializer.encode(%{redirect: redirect})

        Conn.resp(conn, 200, body)
      end
    )

    assert {:ok, redirect} == Redirect.create(token, %{redirect: redirect})
  end

  test "client can request to update an redirect", %{
    bypass: bypass,
    shop: _shop,
    auth_token: token,
    redirect: redirect
  } do
    Bypass.expect_once(
      bypass,
      "PUT",
      "/admin/api/#{Request.version()}/redirects/#{redirect["id"]}.json",
      fn conn ->
        {:ok, body} = JSONSerializer.encode(%{redirect: redirect})

        Conn.resp(conn, 200, body)
      end
    )

    assert {:ok, redirect} == Redirect.update(token, %{"redirect" => redirect})
  end

  test "client can request to delete an redirect", %{
    bypass: bypass,
    shop: _shop,
    auth_token: token,
    redirect: redirect
  } do
    Bypass.expect_once(
      bypass,
      "DELETE",
      "/admin/api/#{Request.version()}/redirects/#{redirect["id"]}.json",
      fn conn ->
        {:ok, body} = JSONSerializer.encode([])

        Conn.resp(conn, 200, body)
      end
    )

    assert {:ok, {:ok, []}} == Redirect.delete(token, redirect["id"])
  end
end
