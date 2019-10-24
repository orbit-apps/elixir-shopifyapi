defmodule ShopifyAPI.Plugs.AdminAuthenticatorTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Plug.Conn
  alias ShopifyAPI.Plugs.AdminAuthenticator
  alias ShopifyAPI.{App, AppServer, AuthToken, AuthTokenServer, Shop, ShopServer}

  @app %App{name: "test"}
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

  describe "without a session and an invalid hmac" do
    test "responds with 401 and halts" do
      params = %{@params | hmac: "invalid"}
      # Create a test connection
      conn =
        :get
        |> conn("/admin/#{@app.name}?" <> URI.encode_query(params))
        |> init_test_session(%{})
        |> Conn.fetch_query_params()

      conn = AdminAuthenticator.call(conn, [])

      assert conn.state == :set
      assert conn.status == 401
      assert conn.resp_body == "Not Authorized."
    end
  end

  describe "without a session" do
    setup do
      # Create a test connection
      conn =
        :get
        |> conn("/admin/#{@app.name}?" <> URI.encode_query(@params))
        |> init_test_session(%{})
        |> Conn.fetch_query_params()

      [conn: conn]
    end

    test "authenticates the hmac", %{conn: conn} do
      conn = AdminAuthenticator.call(conn, [])

      assert conn.state == :unset
      assert conn.status == nil
      assert conn.resp_body == nil
    end

    test "assigns the app, shop, and authtoken", %{conn: conn} do
      conn = AdminAuthenticator.call(conn, [])

      assert conn.assigns.app == @app
      assert conn.assigns.shop == @shop
      assert conn.assigns.auth_token == @auth_token
    end

    test "sets the session but no authtoken", %{conn: conn} do
      conn = AdminAuthenticator.call(conn, [])

      assert Conn.get_session(conn, :shopify_api_admin_authenticated) == true
      assert Conn.get_session(conn, :app_name) == @app.name
      assert Conn.get_session(conn, :shop_domain) == @shop.domain
      assert Conn.get_session(conn, :auth_token) == nil
    end
  end

  describe "with a session" do
    setup do
      # Create a test connection
      conn =
        :get
        |> conn("/admin/#{@app.name}?" <> URI.encode_query(@params))
        |> init_test_session(%{
          app_name: @app.name,
          shop_domain: @shop.domain,
          shopify_api_admin_authenticated: true
        })
        |> Conn.fetch_query_params()

      [conn: conn]
    end

    test "assigns the app, shop, and authtoken", %{conn: conn} do
      conn = AdminAuthenticator.call(conn, [])

      assert conn.assigns.app == @app
      assert conn.assigns.shop == @shop
      assert conn.assigns.auth_token == @auth_token
    end
  end
end
