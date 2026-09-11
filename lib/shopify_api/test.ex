defmodule ShopifyAPI.Test do
  @moduledoc """
  Builders for auth token states your tests need.

  Each function returns a `ShopifyAPI.AuthToken` struct without touching the cache or Shopify.
  Pass the result to `ShopifyAPI.AuthTokenServer.set/2` with `false` to populate the cache
  without invoking your persistence callback.

      token = ShopifyAPI.Test.expiring_token(shop_name: "shop.myshopify.com", app_name: "my-app")
      ShopifyAPI.AuthTokenServer.set(token, false)

  Three builders cover the token lifecycle:

    - `expiring_token/1` — live, both expiries in the future
    - `expired_token/1` — access token expired, refresh token alive (triggers a refresh)
    - `dead_token/1` — both halves expired (returns `{:error, :needs_reacquisition}`)

  A bare `%ShopifyAPI.AuthToken{}` has `refresh_token: nil`, so it behaves as a permanent
  token that is never refreshed.
  """

  alias ShopifyAPI.AuthToken

  @ninety_days :timer.hours(24 * 90)

  @doc """
  Builds a live expiring token with both expiries in the future.

  `ShopifyAPI.AuthToken.fetch/2` returns it without refreshing. Any field can be overridden
  through `attrs`.

  ## Examples

      iex> token = ShopifyAPI.Test.expiring_token(shop_name: "live.myshopify.com", app_name: "my-app")
      iex> ShopifyAPI.AuthTokenServer.set(token, false)
      iex> ShopifyAPI.AuthToken.fetch("live.myshopify.com", "my-app")
      {:ok, token}

  """
  @spec expiring_token(keyword()) :: AuthToken.t()
  def expiring_token(attrs \\ []) do
    build(
      [
        token_expires_at: from_now(:timer.minutes(55)),
        refresh_token: "shprt_test_refresh_token",
        refresh_token_expires_at: from_now(@ninety_days)
      ],
      attrs
    )
  end

  @doc """
  Builds an expiring token whose access token has expired but whose refresh token has not.

  `ShopifyAPI.AuthToken.fetch/2` will refresh before returning, so tests using this need
  Shopify's token endpoint stubbed and the app registered in `ShopifyAPI.AppServer`.

  ## Examples

      iex> token = ShopifyAPI.Test.expired_token()
      iex> DateTime.after?(DateTime.utc_now(), token.token_expires_at)
      true
      iex> DateTime.after?(token.refresh_token_expires_at, DateTime.utc_now())
      true

  """
  @spec expired_token(keyword()) :: AuthToken.t()
  def expired_token(attrs \\ []) do
    build(
      [
        token_expires_at: from_now(-:timer.minutes(5)),
        refresh_token: "shprt_test_refresh_token",
        refresh_token_expires_at: from_now(@ninety_days)
      ],
      attrs
    )
  end

  @doc """
  Builds an expiring token where both halves have expired.

  `ShopifyAPI.AuthToken.fetch/2` returns `{:error, :needs_reacquisition}` without calling
  Shopify.

  ## Examples

      iex> token = ShopifyAPI.Test.dead_token(shop_name: "lapsed.myshopify.com", app_name: "my-app")
      iex> ShopifyAPI.AuthTokenServer.set(token, false)
      iex> ShopifyAPI.AuthToken.fetch("lapsed.myshopify.com", "my-app")
      {:error, :needs_reacquisition}

  """
  @spec dead_token(keyword()) :: AuthToken.t()
  def dead_token(attrs \\ []) do
    build(
      [
        token_expires_at: from_now(-@ninety_days),
        refresh_token: "shprt_test_refresh_token",
        refresh_token_expires_at: from_now(-:timer.hours(1))
      ],
      attrs
    )
  end

  defp build(defaults, attrs) do
    struct!(
      %AuthToken{
        shop_name: "test-shop.myshopify.com",
        app_name: "test-app",
        token: "shpat_test_access_token"
      },
      Keyword.merge(defaults, attrs)
    )
  end

  defp from_now(milliseconds),
    do: DateTime.add(DateTime.utc_now(), milliseconds, :millisecond)
end
