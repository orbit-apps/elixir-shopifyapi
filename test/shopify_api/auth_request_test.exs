defmodule ShopifyAPI.AuthRequestTest do
  # Not async: swaps the top-level :offline_tokens and :expiring settings, which are global.
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog
  import ShopifyAPI.TokenConfigSetup

  alias Plug.Conn
  alias ShopifyAPI.App
  alias ShopifyAPI.AuthRequest
  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.AuthTokenServer
  alias ShopifyAPI.JSONSerializer
  alias ShopifyAPI.TokenMigrationError

  # The app cache is shared across the suite and `AppServer.get_by_client_id/1` matches a single
  # app, so every test module needs a client id of its own.
  @app %App{
    name: "acquisition-test-app",
    client_id: "acquisition-client-id",
    client_secret: "client-secret"
  }

  # A persistence callback whose write always fails, for the migration write-failure test.
  defmodule FailingPersistence do
    @moduledoc false
    def save(_key, _token), do: {:error, :storage_unavailable}
  end

  # A persistence callback that raises with the token in its message, to prove the migration
  # error names the failure without echoing the credentials it was writing.
  defmodule LeakyPersistence do
    @moduledoc false
    def save(_key, token), do: raise("write failed for #{token.token}")
  end

  setup :isolate_token_config

  setup do
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

  defp permanent_token(shop),
    do: %AuthToken{shop_name: shop, app_name: @app.name, token: "shpat_permanent"}

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

    for mode <- [:expiring, :exchange_permanent] do
      test "offline_tokens: #{inspect(mode)} asks for an expiring token on both grants", %{
        bypass: bypass,
        shop: shop
      } do
        Application.put_env(:shopify_api, :offline_tokens, unquote(mode))

        capture_body(bypass)
        AuthRequest.post(@app, shop, "auth-code")
        assert_receive {:body, %{"expiring" => 1}}

        capture_body(bypass)
        AuthRequest.request_offline_access_token(@app, shop, "session-token")
        assert_receive {:body, %{"expiring" => 1}}
      end
    end

    test "offline_tokens: :permanent asks for a permanent token on both grants", %{
      bypass: bypass,
      shop: shop
    } do
      # Wins over the legacy flag, so a leftover `expiring: true` cannot override it.
      Application.put_env(:shopify_api, :expiring, true)
      Application.put_env(:shopify_api, :offline_tokens, :permanent)

      capture_body(bypass, Map.take(@pair, [:access_token]))
      AuthRequest.post(@app, shop, "auth-code")
      assert_receive {:body, body}
      refute Map.has_key?(body, "expiring")

      capture_body(bypass, Map.take(@pair, [:access_token]))
      AuthRequest.request_offline_access_token(@app, shop, "session-token")
      assert_receive {:body, body}
      refute Map.has_key?(body, "expiring")
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

  describe "migrate_offline_access_token/2" do
    test "exchanges the permanent token for an expiring pair, always asking for expiring", %{
      bypass: bypass,
      shop: shop
    } do
      # Migration ignores the setting: an already-installed shop must move regardless.
      Application.put_env(:shopify_api, :offline_tokens, :permanent)
      capture_body(bypass)

      assert {:ok, _token} = AuthRequest.migrate_offline_access_token(@app, permanent_token(shop))

      assert_receive {:body, body}
      assert body["expiring"] == 1
      assert body["subject_token"] == "shpat_permanent"
      assert body["subject_token_type"] =~ "offline-access-token"
      assert body["requested_token_type"] =~ "offline-access-token"
      assert body["grant_type"] == "urn:ietf:params:oauth:grant-type:token-exchange"
    end

    test "stores the new pair, keeping the shop and app", %{bypass: bypass, shop: shop} do
      capture_body(bypass)

      assert {:ok, token} = AuthRequest.migrate_offline_access_token(@app, permanent_token(shop))

      assert token.token == "shpat_acquired"
      assert token.refresh_token == "shprt_acquired"
      assert token.shop_name == shop
      assert token.app_name == @app.name
      assert DateTime.after?(token.refresh_token_expires_at, token.token_expires_at)
      assert {:ok, ^token} = AuthTokenServer.get(shop, @app.name)
    end

    test "refuses a token that already has a refresh token, without calling Shopify", %{
      bypass: bypass,
      shop: shop
    } do
      # With Bypass down, any HTTP call would surface as a failure rather than :already_expiring.
      Bypass.down(bypass)
      token = %{permanent_token(shop) | refresh_token: "shprt_existing"}

      assert {:error, :already_expiring} = AuthRequest.migrate_offline_access_token(@app, token)
    end

    test "returns :invalid_subject_token for an already-spent subject token", %{
      bypass: bypass,
      shop: shop
    } do
      Bypass.expect_once(bypass, "POST", "/admin/oauth/access_token", fn conn ->
        body = JSONSerializer.encode!(%{error: "invalid_subject_token"})
        Conn.resp(conn, 400, body)
      end)

      log =
        capture_log(fn ->
          assert {:error, :invalid_subject_token} =
                   AuthRequest.migrate_offline_access_token(@app, permanent_token(shop))
        end)

      assert {:error, :not_found} = AuthTokenServer.get(shop, @app.name)
      assert log =~ "already migrated"
    end

    test "returns Shopify's status and body for other exchange failures", %{
      bypass: bypass,
      shop: shop
    } do
      Bypass.expect_once(bypass, "POST", "/admin/oauth/access_token", fn conn ->
        Conn.resp(conn, 500, ~s({"errors":"Internal Server Error"}))
      end)

      log =
        capture_log(fn ->
          assert {:error,
                  {:failed_migrating_offline_token,
                   %{status: 500, body: ~s({"errors":"Internal Server Error"})}}} =
                   AuthRequest.migrate_offline_access_token(@app, permanent_token(shop))
        end)

      assert {:error, :not_found} = AuthTokenServer.get(shop, @app.name)
      assert log =~ "error migrating token"
    end

    test "returns the connection error when Shopify never answers", %{
      bypass: bypass,
      shop: shop
    } do
      Bypass.down(bypass)

      capture_log(fn ->
        assert {:error, {:failed_migrating_offline_token, %{reason: :econnrefused}}} =
                 AuthRequest.migrate_offline_access_token(@app, permanent_token(shop))
      end)
    end

    test "raises when the exchange succeeds but the pair cannot be stored", %{
      bypass: bypass,
      shop: shop
    } do
      # The old token is revoked the moment the exchange returns, so a lost write is unrecoverable.
      Application.put_env(:shopify_api, AuthTokenServer,
        persistence: {FailingPersistence, :save, []}
      )

      on_exit(fn -> Application.delete_env(:shopify_api, AuthTokenServer) end)

      capture_body(bypass)

      assert_raise TokenMigrationError, ~r/could not store the new pair/, fn ->
        AuthRequest.migrate_offline_access_token(@app, permanent_token(shop))
      end
    end

    test "raises without echoing the credentials a leaking write failure exposes", %{
      bypass: bypass,
      shop: shop
    } do
      Application.put_env(:shopify_api, AuthTokenServer,
        persistence: {LeakyPersistence, :save, []}
      )

      on_exit(fn -> Application.delete_env(:shopify_api, AuthTokenServer) end)

      capture_body(bypass)

      error =
        assert_raise TokenMigrationError, fn ->
          AuthRequest.migrate_offline_access_token(@app, permanent_token(shop))
        end

      # The message names the failure's type, never the token the callback was mid-write on.
      refute error.message =~ "shpat_acquired"
    end

    test "raises on a successful exchange whose body is not JSON", %{bypass: bypass, shop: shop} do
      Bypass.expect_once(bypass, "POST", "/admin/oauth/access_token", fn conn ->
        Conn.resp(conn, 200, "<html>not json</html>")
      end)

      assert_raise TokenMigrationError, ~r/not JSON/, fn ->
        AuthRequest.migrate_offline_access_token(@app, permanent_token(shop))
      end

      assert {:error, :not_found} = AuthTokenServer.get(shop, @app.name)
    end

    test "raises on a successful exchange that returns an incomplete pair", %{
      bypass: bypass,
      shop: shop
    } do
      capture_body(bypass, Map.delete(@pair, :refresh_token))

      error =
        assert_raise TokenMigrationError, ~r/incomplete pair/, fn ->
          AuthRequest.migrate_offline_access_token(@app, permanent_token(shop))
        end

      # The 200 body carried the access token, but the raised error must not repeat it.
      refute error.message =~ "shpat_acquired"
      assert {:error, :not_found} = AuthTokenServer.get(shop, @app.name)
    end
  end
end
