defmodule ShopifyAPI.Plugs.AuthShopSessionTokenTest do
  # Not async: the exchange test asserts on captured logs, which would pick up output from tests
  # running alongside it.
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog
  import Plug.Test
  import ShopifyAPI.Factory
  import ShopifyAPI.SessionTokenSetup

  alias Plug.Conn
  alias ShopifyAPI.AppServer
  alias ShopifyAPI.AuthTokenServer
  alias ShopifyAPI.Plugs.AuthShopSessionToken
  alias ShopifyAPI.ShopServer

  setup do
    app = build(:app)
    AppServer.set(app)
    [app: app]
  end

  # Sends a request carrying a session token for the shop. A live online token is cached first,
  # so the offline token alone decides the outcome.
  defp call_plug(app, shop) do
    [online_token: online_token] = online_token(%{shop: shop})

    [jwt_session_token: session_token] =
      jwt_session_token(%{app: app, shop: shop, online_token: online_token})

    :get
    |> conn("/")
    |> Conn.put_req_header("authorization", "Bearer " <> session_token)
    |> AuthShopSessionToken.call([])
  end

  test "assigns the shop's cached offline token", %{app: app} do
    shop = build(:shop)
    ShopServer.set(shop)
    [offline_token: offline_token] = offline_token(%{shop: shop})

    conn = call_plug(app, shop)

    refute conn.halted
    assert conn.assigns.auth_token == offline_token
  end

  test "exchanges the session token when the cached refresh token is dead", %{app: app} do
    # `myshopify_domain/1` keeps only the host of the `dest` claim, so the exchange can't be
    # pointed at Bypass. It goes to localhost, where nothing listens, so the request still ends
    # in a 401 — the log is what shows an exchange was attempted instead of the dead token
    # ending the request.
    shop = %ShopifyAPI.Shop{domain: "localhost"}
    ShopServer.set(shop)
    dead = ShopifyAPI.Test.dead_token(shop_name: shop.domain, app_name: app.name)
    AuthTokenServer.set(dead, false)

    log = capture_log(fn -> assert %{status: 401} = call_plug(app, shop) end)

    assert log =~ "exchanging session token"
  end

  test "raises rather than responding 401 when a refresh fails", %{app: app} do
    # As above, the refresh can't be pointed at Bypass, and at localhost nothing answers it with a
    # pair. A failed refresh is not a bad session, so it must not end in a 401.
    shop = %ShopifyAPI.Shop{domain: "localhost"}
    ShopServer.set(shop)
    expired = ShopifyAPI.Test.expired_token(shop_name: shop.domain, app_name: app.name)
    AuthTokenServer.set(expired, false)

    assert_raise ShopifyAPI.TokenRefreshError, fn -> call_plug(app, shop) end
  end
end
