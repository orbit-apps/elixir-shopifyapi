defmodule ShopifyAPI.RefreshTest do
  # Async-safe: every token here is keyed on an app name no other test uses, and the assertions
  # filter the shared cache down to it.
  use ExUnit.Case, async: true

  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.AuthTokenServer
  alias ShopifyAPI.Refresh

  # Each test gets its own app name to isolate within the shared cache.
  setup context do
    {:ok, app: "refresh-sweep-#{:erlang.phash2(context.test)}"}
  end

  defp cache(app, shop_name, attrs) do
    token = ShopifyAPI.Test.expiring_token([shop_name: shop_name, app_name: app] ++ attrs)
    AuthTokenServer.set(token, false)
    token
  end

  defp in_days(days), do: DateTime.shift(DateTime.utc_now(), day: days)

  defp swept(app, days) do
    Duration.new!(day: days)
    |> Refresh.shops_needing_refresh()
    |> Enum.filter(&(&1.app_name == app))
    |> Enum.map(& &1.shop_name)
    |> Enum.sort()
  end

  describe "shops_needing_refresh/1" do
    test "selects pairs older than the given age", %{app: app} do
      # Age is read off the access token's expiry, which every refresh sets an hour out.
      cache(app, "stale.myshopify.com", token_expires_at: in_days(-30))
      cache(app, "fresh.myshopify.com", token_expires_at: in_days(-5))

      assert swept(app, 28) == ["stale.myshopify.com"]
    end

    test "leaves a pair refreshed moments ago alone", %{app: app} do
      # Its access token expires in the future, so the pair is barely minutes old.
      cache(app, "just-refreshed.myshopify.com", token_expires_at: in_days(1))

      assert swept(app, 28) == []
    end

    test "ignores permanent tokens", %{app: app} do
      cache(app, "permanent.myshopify.com",
        refresh_token: nil,
        token_expires_at: nil,
        refresh_token_expires_at: nil
      )

      assert swept(app, 1) == []
    end

    test "ignores refresh tokens that are past their own expiry", %{app: app} do
      # Dead beyond replay, so a sweep should not spend a request discovering that.
      cache(app, "lapsed.myshopify.com",
        token_expires_at: in_days(-95),
        refresh_token_expires_at: in_days(-5)
      )

      assert swept(app, 28) == []
    end

    test "includes a token with no access-token expiry to date it by", %{app: app} do
      cache(app, "no-expiry.myshopify.com", token_expires_at: nil)

      assert swept(app, 28) == ["no-expiry.myshopify.com"]
    end
  end

  describe "await_or_run/1" do
    test "uses the cached token when ours has already been replaced", %{app: app} do
      # When the cache already holds a newer token, `await_or_run/1` returns it instead of
      # refreshing with the stale one whose refresh token may already be spent.
      stale =
        ShopifyAPI.Test.expiring_token(
          shop_name: "raced.myshopify.com",
          app_name: app,
          token: "shpat_stale"
        )

      replacement = %{stale | token: "shpat_replacement"}
      AuthTokenServer.set(replacement, false)

      # The app is deliberately not registered in AppServer, so any attempt to actually refresh
      # raises rather than quietly passing.
      assert {:ok, ^replacement} = Refresh.await_or_run(stale)
    end
  end

  describe "run/1" do
    test "refuses a permanent token", %{app: app} do
      token = %AuthToken{shop_name: "permanent.myshopify.com", app_name: app}

      assert_raise ArgumentError, ~r/no refresh token/, fn -> Refresh.run(token) end
    end

    test "refuses a token naming an app that is not registered" do
      token = ShopifyAPI.Test.expiring_token(app_name: "never-registered-app")

      assert_raise ArgumentError, ~r/not a registered app/, fn -> Refresh.run(token) end
    end
  end
end
