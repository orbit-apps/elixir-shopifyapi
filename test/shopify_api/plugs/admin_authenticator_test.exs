defmodule ShopifyAPI.Plugs.AdminAuthenticatorTest do
  use ExUnit.Case, async: true
  import Plug.Test

  alias Plug.Conn
  alias ShopifyAPI.Plugs.AdminAuthenticator
  alias ShopifyAPI.{App, AppServer, AuthToken, AuthTokenServer, Shop, ShopServer}

  @app %App{name: "test"}
  @uninstalled_shop "uninstalled.myshopify.com"
  @shop %Shop{domain: "test-shop.example.com"}
  @auth_token %AuthToken{app_name: @app.name, shop_name: @shop.domain, token: "test"}
  @params %{
    test: "test",
    shop: @shop.domain,
    hmac: "2ebfc11fdbff86c17d688617e0ce54ca6ae1cf2a8ddcdcb2226dfbf8d02374e6"
  }

  setup_all do
    ShopServer.set(@shop)
    AppServer.set(@app)
    AuthTokenServer.set(@auth_token)
    :ok
  end

  #  describe "with an invalid hmac" do
  #    test "responds with 401 and halts" do
  #      params = %{@params | hmac: "invalid"}
  #      # Create a test connection
  #      conn =
  #        :get
  #        |> conn("/admin/#{@app.name}?" <> URI.encode_query(params))
  #        |> init_test_session(%{})
  #        |> Conn.fetch_query_params()
  #        |> AdminAuthenticator.call([])
  #
  #      assert conn.state == :set
  #      assert conn.status == 401
  #      assert conn.resp_body == "Not Authorized."
  #    end
  #  end
  #
  #  describe "with a valid hmac" do
  #    setup do
  #      # Create a test connection
  #      conn =
  #        :get
  #        |> conn("/admin/#{@app.name}?" <> URI.encode_query(@params))
  #        |> init_test_session(%{})
  #        |> Conn.fetch_query_params()
  #
  #      [conn: conn]
  #    end
  #
  #    test "assigns the app, shop, and authtoken", %{conn: conn} do
  #      conn = AdminAuthenticator.call(conn, [])
  #
  #      assert conn.assigns.app == @app
  #      assert conn.assigns.shop == @shop
  #      assert conn.assigns.auth_token == @auth_token
  #    end
  #  end

  describe "without an installed shop" do
    setup do
      params = %{
        @params
        | shop: @uninstalled_shop,
          hmac: "a750bd98910efb8729f2edc4e444a733ce1a6692a09181e43cfae0e00a61226a"
      }

      # Create a test connection
      conn =
        :get
        |> conn("/admin/#{@app.name}?" <> URI.encode_query(params))
        |> init_test_session(%{})
        |> Conn.fetch_query_params()

      [conn: conn]
    end
  end

  describe "without an hmac" do
    setup do
      params = %{shop: @uninstalled_shop}

      # Create a test connection
      conn =
        :get
        |> conn("/admin/#{@app.name}?" <> URI.encode_query(params))
        |> init_test_session(%{})
        |> Conn.fetch_query_params()

      [conn: conn]
    end

    test "plug does not halt", %{conn: conn} do
      conn = AdminAuthenticator.call(conn, shopify_mount_path: "/shop")

      refute conn.halted
    end
  end
end
