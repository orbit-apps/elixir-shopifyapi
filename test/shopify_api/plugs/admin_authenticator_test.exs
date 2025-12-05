defmodule ShopifyAPI.Plugs.AdminAuthenticatorTest do
  use ExUnit.Case, async: true

  import Plug.Test
  import ShopifyAPI.Factory
  import ShopifyAPI.SessionTokenSetup

  alias Plug.Conn
  alias ShopifyAPI.{AppServer, ShopServer}
  alias ShopifyAPI.Plugs.AdminAuthenticator
  alias ShopifyAPI.ShopifyValidationSetup

  @uninstalled_shop "uninstalled.myshopify.com"

  setup_all do
    app = build(:app)
    shop = build(:shop)
    [offline_token: offline_token] = offline_token(%{shop: shop})
    [online_token: online_token] = online_token(%{shop: shop})

    [jwt_session_token: jwt_session_token] =
      jwt_session_token(%{app: app, shop: shop, online_token: online_token})

    ShopServer.set(shop)
    AppServer.set(app)

    params = %{
      test: "test",
      shop: shop.domain,
      id_token: jwt_session_token
    }

    [
      app: app,
      shop: shop,
      offline_token: offline_token,
      online_token: online_token,
      jwt_session_token: jwt_session_token,
      params: ShopifyValidationSetup.params_append_hmac(app, params)
    ]
  end

  describe "with an invalid hmac" do
    test "responds with 401 and halts", %{app: app, params: params} do
      params = %{params | hmac: "invalid"}
      # Create a test connection
      conn =
        :get
        |> conn("/admin/#{app.name}?" <> URI.encode_query(params))
        |> init_test_session(%{})
        |> Conn.fetch_query_params()
        |> AdminAuthenticator.call([])

      assert conn.state == :set
      assert conn.status == 401
      assert conn.resp_body == "Not Authorized."
    end
  end

  describe "with a valid hmac" do
    setup(%{app: app, params: params}) do
      # Create a test connection
      conn =
        :get
        |> conn("/admin/#{app.name}?" <> URI.encode_query(params))
        |> init_test_session(%{})
        |> Conn.fetch_query_params()

      [conn: conn]
    end

    test "assigns the app, shop, and authtoken", %{
      conn: conn,
      app: app,
      shop: shop,
      online_token: online_token,
      offline_token: offline_token
    } do
      conn = AdminAuthenticator.call(conn, [])

      assert conn.assigns.app == app
      assert conn.assigns.shop == shop
      assert conn.assigns.auth_token == offline_token
      assert conn.assigns.user_token == online_token
    end
  end

  describe "without an hmac" do
    setup(%{app: app}) do
      params = %{shop: @uninstalled_shop}

      # Create a test connection
      conn =
        :get
        |> conn("/admin/#{app.name}?" <> URI.encode_query(params))
        |> init_test_session(%{})
        |> Conn.fetch_query_params()

      [conn: conn, params: params]
    end

    test "plug does not halt", %{conn: conn} do
      conn = AdminAuthenticator.call(conn, shopify_mount_path: "/shop")

      refute conn.halted
    end
  end
end
