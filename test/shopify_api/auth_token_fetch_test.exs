defmodule ShopifyAPI.AuthTokenFetchTest do
  # Not async: shares the public token cache and a Bypass port with no other test.
  use ExUnit.Case, async: false

  alias Plug.Conn
  alias ShopifyAPI.App
  alias ShopifyAPI.AppServer
  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.AuthTokenServer
  alias ShopifyAPI.JSONSerializer
  alias ShopifyAPI.TokenRefreshError

  @app_name "fetch-test-app"
  @hour :timer.hours(1)
  @ninety_days 7_775_999

  setup do
    AppServer.set(%App{name: @app_name, client_id: "client-id", client_secret: "client-secret"})

    bypass = Bypass.open()
    {:ok, bypass: bypass, shop: "localhost:#{bypass.port}"}
  end

  defp cache(shop, attrs) do
    token =
      struct!(
        %AuthToken{shop_name: shop, app_name: @app_name, token: "shpat_current"},
        attrs
      )

    AuthTokenServer.set(token, false)
    token
  end

  defp from_now(milliseconds),
    do: DateTime.add(DateTime.utc_now(), milliseconds, :millisecond)

  defp respond_with_pair(bypass, body) do
    test_pid = self()

    Bypass.expect_once(bypass, "POST", "/admin/oauth/access_token", fn conn ->
      send(test_pid, :refresh_requested)
      Conn.resp(conn, 200, JSONSerializer.encode!(body))
    end)
  end

  defp fresh_pair do
    %{
      access_token: "shpat_refreshed",
      expires_in: 3600,
      refresh_token: "shprt_refreshed",
      refresh_token_expires_in: @ninety_days
    }
  end

  describe "cache misses and permanent tokens" do
    test "reports a shop with nothing cached as not found" do
      assert {:error, :not_found} = AuthToken.fetch("never-installed.myshopify.com", @app_name)
    end

    test "returns a permanent token untouched", %{shop: shop} do
      token = cache(shop, token_expires_at: nil, refresh_token: nil)

      assert {:ok, ^token} = AuthToken.fetch(shop, @app_name)
    end

    test "ignores a stale expiry on a permanent token", %{shop: shop} do
      # A nil refresh token settles it before any expiry is consulted.
      token = cache(shop, token_expires_at: from_now(-@hour), refresh_token: nil)

      assert {:ok, ^token} = AuthToken.fetch(shop, @app_name)
    end
  end

  describe "expiring tokens with life left" do
    test "returns a comfortably live token without refreshing", %{shop: shop} do
      token =
        cache(shop,
          token_expires_at: from_now(@hour),
          refresh_token: "shprt_current",
          refresh_token_expires_at: from_now(:timer.hours(24 * 90))
        )

      assert {:ok, ^token} = AuthToken.fetch(shop, @app_name)
      refute_receive :refresh_requested, 100
    end

    test "keeps serving a token inside the threshold whose refresh token has died", %{shop: shop} do
      # Inside the threshold but the refresh token is dead. The access token still works, so
      # it is served without attempting a refresh. `status/2` agrees.
      token =
        cache(shop,
          token_expires_at: from_now(:timer.minutes(4)),
          refresh_token: "shprt_dead",
          refresh_token_expires_at: from_now(-@hour)
        )

      assert {:ok, ^token} = AuthToken.fetch(shop, @app_name)
      assert :ok = AuthToken.status(shop, @app_name)
      refute_receive :refresh_requested, 100
    end

    test "keeps serving a live access token whose refresh token has died", %{shop: shop} do
      # A dead refresh token is only fatal once the access token has also expired.
      token =
        cache(shop,
          token_expires_at: from_now(@hour),
          refresh_token: "shprt_dead",
          refresh_token_expires_at: from_now(-@hour)
        )

      assert {:ok, ^token} = AuthToken.fetch(shop, @app_name)
    end
  end

  describe "reacquisition" do
    test "reports a spent access token with a dead refresh token", %{shop: shop} do
      cache(shop,
        token_expires_at: from_now(-@hour),
        refresh_token: "shprt_dead",
        refresh_token_expires_at: from_now(-@hour)
      )

      assert {:error, :needs_reacquisition} = AuthToken.fetch(shop, @app_name)
      refute_receive :refresh_requested, 100
    end
  end

  describe "background refresh" do
    test "returns the current token and refreshes out of band", %{bypass: bypass, shop: shop} do
      respond_with_pair(bypass, fresh_pair())

      token =
        cache(shop,
          # Inside the default five-minute threshold, but not yet expired.
          token_expires_at: from_now(:timer.minutes(2)),
          refresh_token: "shprt_current",
          refresh_token_expires_at: from_now(:timer.hours(24 * 90))
        )

      # The caller is handed what it already had rather than waiting.
      assert {:ok, ^token} = AuthToken.fetch(shop, @app_name)

      assert_receive :refresh_requested, 1_000
      assert eventually_cached(shop, "shpat_refreshed")
    end
  end

  describe "synchronous refresh" do
    test "refreshes an expired token before returning it", %{bypass: bypass, shop: shop} do
      respond_with_pair(bypass, fresh_pair())

      cache(shop,
        token_expires_at: from_now(-@hour),
        refresh_token: "shprt_current",
        refresh_token_expires_at: from_now(:timer.hours(24 * 90))
      )

      assert {:ok, refreshed} = AuthToken.fetch(shop, @app_name)
      assert refreshed.token == "shpat_refreshed"
      assert refreshed.refresh_token == "shprt_refreshed"
      assert DateTime.after?(refreshed.token_expires_at, DateTime.utc_now())
    end

    test "keeps what a refresh response does not describe", %{bypass: bypass, shop: shop} do
      # A refresh response carries credentials but not shop metadata like `plus`.
      respond_with_pair(bypass, fresh_pair())

      cache(shop,
        plus: true,
        timestamp: 1_600_000_000,
        token_expires_at: from_now(-@hour),
        refresh_token: "shprt_current",
        refresh_token_expires_at: from_now(:timer.hours(24 * 90))
      )

      assert {:ok, refreshed} = AuthToken.fetch(shop, @app_name)
      assert refreshed.token == "shpat_refreshed"
      assert refreshed.plus
      assert refreshed.timestamp == 1_600_000_000
    end

    test "reports reacquisition when Shopify rejects the refresh token", %{
      bypass: bypass,
      shop: shop
    } do
      Bypass.expect_once(bypass, "POST", "/admin/oauth/access_token", fn conn ->
        Conn.resp(conn, 401, ~s({"error":"invalid_request"}))
      end)

      cache(shop,
        token_expires_at: from_now(-@hour),
        refresh_token: "shprt_superseded",
        refresh_token_expires_at: from_now(:timer.hours(24 * 90))
      )

      assert {:error, :needs_reacquisition} = AuthToken.fetch(shop, @app_name)
    end

    test "raises on a transient Shopify failure", %{bypass: bypass, shop: shop} do
      Bypass.expect_once(bypass, "POST", "/admin/oauth/access_token", fn conn ->
        Conn.resp(conn, 503, "")
      end)

      cache(shop,
        token_expires_at: from_now(-@hour),
        refresh_token: "shprt_current",
        refresh_token_expires_at: from_now(:timer.hours(24 * 90))
      )

      assert_raise TokenRefreshError, fn -> AuthToken.fetch(shop, @app_name) end
    end

    test "refuses a pair whose refresh token expires no later than its access token", %{
      bypass: bypass,
      shop: shop
    } do
      # Observed from Shopify in July 2026. The pair is rejected because persisting it would
      # leave the shop unrefreshable once the access token expires.
      respond_with_pair(bypass, %{fresh_pair() | refresh_token_expires_in: 3599})

      original =
        cache(shop,
          token_expires_at: from_now(-@hour),
          refresh_token: "shprt_current",
          refresh_token_expires_at: from_now(:timer.hours(24 * 90))
        )

      assert_raise TokenRefreshError, ~r/no later than/, fn ->
        AuthToken.fetch(shop, @app_name)
      end

      assert {:ok, ^original} = AuthTokenServer.get(shop, @app_name)
    end

    test "refuses a refresh response missing part of the pair", %{bypass: bypass, shop: shop} do
      # A refresh always returns a complete rotating pair; a response missing any of the four
      # fields is rejected rather than cached as a token with nil expiries.
      respond_with_pair(bypass, Map.delete(fresh_pair(), :refresh_token_expires_in))

      original =
        cache(shop,
          token_expires_at: from_now(-@hour),
          refresh_token: "shprt_current",
          refresh_token_expires_at: from_now(:timer.hours(24 * 90))
        )

      assert_raise TokenRefreshError, ~r/incomplete pair/, fn ->
        AuthToken.fetch(shop, @app_name)
      end

      assert {:ok, ^original} = AuthTokenServer.get(shop, @app_name)
    end

    test "refuses a refresh response that is not JSON", %{bypass: bypass, shop: shop} do
      # A truncated body can still carry credentials, so the error names the problem without
      # quoting the body.
      Bypass.expect_once(bypass, "POST", "/admin/oauth/access_token", fn conn ->
        Conn.resp(conn, 200, ~s({"access_token":"shpat_refreshed","expires_in":))
      end)

      original =
        cache(shop,
          token_expires_at: from_now(-@hour),
          refresh_token: "shprt_current",
          refresh_token_expires_at: from_now(:timer.hours(24 * 90))
        )

      error =
        assert_raise TokenRefreshError, ~r/not JSON/, fn ->
          AuthToken.fetch(shop, @app_name)
        end

      refute error.message =~ "shpat_refreshed"
      assert {:ok, ^original} = AuthTokenServer.get(shop, @app_name)
    end
  end

  describe "JWTSessionToken.get_offline_token/2" do
    # `myshopify_domain/1` keeps only the host of the `dest` claim, so a Bypass `localhost:port`
    # shop name cannot survive the round trip. These key on a bare host instead, which is also
    # why the exchange below is asserted on reaching Shopify rather than on its result.
    defp jwt_for(domain),
      do: %JOSE.JWT{fields: %{"dest" => "https://#{domain}", "aud" => "client-id"}}

    test "exchanges rather than handing back a dead cached token" do
      # A bare cache read would return the dead token. `get_offline_token/2` must detect that
      # and fall through to an exchange instead.
      cache("localhost",
        token_expires_at: from_now(-@hour),
        refresh_token: "shprt_dead",
        refresh_token_expires_at: from_now(-@hour)
      )

      # Nothing listens on the default port, so the exchange fails immediately. That failure is
      # the assertion: reaching an exchange at all proves the dead token was not handed back.
      assert {:error, :failed_fetching_offline_token} =
               ShopifyAPI.JWTSessionToken.get_offline_token(jwt_for("localhost"), "session-token")
    end

    test "raises rather than exchanging when a refresh fails" do
      # The refresh goes to localhost too, where nothing answers it with a pair. That is a
      # transient failure, not a rejected refresh token, so it must not fall through to an
      # exchange, which would return an error rather than raise.
      cache("localhost",
        token_expires_at: from_now(-@hour),
        refresh_token: "shprt_current",
        refresh_token_expires_at: from_now(:timer.hours(24 * 90))
      )

      assert_raise TokenRefreshError, fn ->
        ShopifyAPI.JWTSessionToken.get_offline_token(jwt_for("localhost"), "session-token")
      end
    end

    test "returns a live cached token without exchanging" do
      domain = "jwt-live.myshopify.com"

      token =
        cache(domain,
          token_expires_at: from_now(@hour),
          refresh_token: "shprt_current",
          refresh_token_expires_at: from_now(:timer.hours(24 * 90))
        )

      # Getting the cached struct back unchanged is the proof: an exchange would have replaced
      # it, and there is nothing for one to succeed against here.
      assert {:ok, ^token} =
               ShopifyAPI.JWTSessionToken.get_offline_token(jwt_for(domain), "session-token")
    end
  end

  describe "status/2" do
    test "calls an expired but refreshable token usable", %{shop: shop} do
      cache(shop,
        token_expires_at: from_now(-@hour),
        refresh_token: "shprt_current",
        refresh_token_expires_at: from_now(:timer.hours(24 * 90))
      )

      assert :ok = AuthToken.status(shop, @app_name)
      # Does not contact Shopify.
      refute_receive :refresh_requested, 100
    end

    test "calls a token past reviving needs_reacquisition", %{shop: shop} do
      cache(shop,
        token_expires_at: from_now(-@hour),
        refresh_token: "shprt_dead",
        refresh_token_expires_at: from_now(-@hour)
      )

      assert :needs_reacquisition = AuthToken.status(shop, @app_name)
    end

    test "calls a permanent token usable", %{shop: shop} do
      cache(shop, refresh_token: nil, token_expires_at: nil)

      assert :ok = AuthToken.status(shop, @app_name)
    end
  end

  defp eventually_cached(shop, expected_token, attempts \\ 50) do
    case AuthTokenServer.get(shop, @app_name) do
      {:ok, %AuthToken{token: ^expected_token}} ->
        true

      _ when attempts > 0 ->
        Process.sleep(20)
        eventually_cached(shop, expected_token, attempts - 1)

      _ ->
        false
    end
  end
end
