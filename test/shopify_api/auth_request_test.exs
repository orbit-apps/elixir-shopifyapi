defmodule ShopifyAPI.AuthRequestTest do
  # Not async: swaps the top-level :expiring setting, which is global.
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Plug.Conn
  alias ShopifyAPI.App
  alias ShopifyAPI.AuthRequest
  alias ShopifyAPI.AuthTokenServer
  alias ShopifyAPI.JSONSerializer

  # The app cache is shared across the suite and `AppServer.get_by_client_id/1` matches a single
  # app, so every test module needs a client id of its own.
  @app %App{
    name: "acquisition-test-app",
    client_id: "acquisition-client-id",
    client_secret: "client-secret"
  }

  setup do
    previous = Application.get_env(:shopify_api, :expiring)

    on_exit(fn ->
      if previous do
        Application.put_env(:shopify_api, :expiring, previous)
      else
        Application.delete_env(:shopify_api, :expiring)
      end
    end)

    bypass = Bypass.open()
    {:ok, bypass: bypass, shop: "localhost:#{bypass.port}"}
  end

  @pair %{
    access_token: "shpat_acquired",
    expires_in: 3600,
    refresh_token: "shprt_acquired",
    refresh_token_expires_in: 7_775_999
  }

  # Captures the JSON body the library posted to the token endpoint.
  defp capture_body(bypass, response \\ @pair) do
    test_pid = self()

    Bypass.expect_once(bypass, "POST", "/admin/oauth/access_token", fn conn ->
      {:ok, body, conn} = Conn.read_body(conn)
      send(test_pid, {:body, JSONSerializer.decode!(body)})

      Conn.resp(conn, 200, JSONSerializer.encode!(response))
    end)
  end

  describe "expiring: 1 on acquisition" do
    test "the auth code grant asks for an expiring token when configured", %{
      bypass: bypass,
      shop: shop
    } do
      Application.put_env(:shopify_api, :expiring, true)
      capture_body(bypass)

      AuthRequest.post(@app, shop, "auth-code")

      assert_receive {:body, body}
      assert body["expiring"] == 1
    end

    test "the auth code grant asks for a permanent token when not configured", %{
      bypass: bypass,
      shop: shop
    } do
      Application.put_env(:shopify_api, :expiring, false)
      capture_body(bypass)

      AuthRequest.post(@app, shop, "auth-code")

      assert_receive {:body, body}
      refute Map.has_key?(body, "expiring")
    end

    test "token exchange asks for an expiring token when configured", %{
      bypass: bypass,
      shop: shop
    } do
      Application.put_env(:shopify_api, :expiring, true)
      capture_body(bypass)

      AuthRequest.request_offline_access_token(@app, shop, "session-token")

      assert_receive {:body, body}
      assert body["expiring"] == 1
      assert body["requested_token_type"] =~ "offline-access-token"
    end

    test "the OAuth code grant parses the pair out of the response", %{
      bypass: bypass,
      shop: shop
    } do
      # App.fetch_token/3 is called from the OAuth redirect and must parse the full pair.
      Application.put_env(:shopify_api, :expiring, true)
      capture_body(bypass)

      assert {:ok, token} = ShopifyAPI.App.fetch_token(@app, shop, "auth-code")

      assert token.token == "shpat_acquired"
      assert token.refresh_token == "shprt_acquired"
      assert DateTime.after?(token.token_expires_at, DateTime.utc_now())
      assert DateTime.after?(token.refresh_token_expires_at, token.token_expires_at)
    end

    test "a refresh never asks, whatever the setting", %{bypass: bypass, shop: shop} do
      # Shopify does not accept `expiring` on a refresh grant.
      Application.put_env(:shopify_api, :expiring, true)
      capture_body(bypass)

      token =
        ShopifyAPI.Test.expiring_token(shop_name: shop, app_name: @app.name)

      AuthRequest.refresh_offline_access_token(@app, token)

      assert_receive {:body, body}
      refute Map.has_key?(body, "expiring")
      assert body["grant_type"] == "refresh_token"
    end
  end

  describe "acquisition rejects an unusable pair" do
    test "token exchange stores nothing when part of the pair is missing", %{
      bypass: bypass,
      shop: shop
    } do
      capture_body(bypass, Map.delete(@pair, :refresh_token))

      log =
        capture_log(fn ->
          assert {:error, :failed_fetching_offline_token} =
                   AuthRequest.request_offline_access_token(@app, shop, "session-token")
        end)

      assert {:error, :not_found} = AuthTokenServer.get(shop, @app.name)
      # The log names the problem, never the response body, which carries the credentials.
      assert log =~ "incomplete_pair"
      refute log =~ "shpat_acquired"
    end

    test "the OAuth code grant rejects an incomplete pair", %{bypass: bypass, shop: shop} do
      capture_body(bypass, Map.delete(@pair, :refresh_token))

      capture_log(fn ->
        assert {:error, _} = App.fetch_token(@app, shop, "auth-code")
      end)
    end
  end
end
