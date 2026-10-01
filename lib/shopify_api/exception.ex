defmodule ShopifyAPI.ShopUnavailableError do
  defexception message: "Shop Unavailable"
end

defmodule ShopifyAPI.ShopNotFoundError do
  defexception message: "Shop Not Found"
end

defmodule ShopifyAPI.ShopAuthError do
  defexception message: "Invalid API key"
end

defmodule ShopifyAPI.TokenPersistenceError do
  defexception message: "Auth token could not be persisted"
end

defmodule ShopifyAPI.TokenRefreshError do
  @moduledoc """
  Raised when refreshing an expiring offline token fails for any reason other than a dead
  refresh token, such as Shopify erroring, timing out, or answering with an unusable pair.

  Also raised when `ShopifyAPI.AuthToken.fetch/2` exchanges a permanent token under
  `offline_tokens: :exchange_permanent` and the exchange fails before Shopify revokes the
  permanent token. Shopify has not revoked it, so the next fetch can safely try again.

  The library treats these failures as transient, so Plug renders this exception as a `503`.
  A dead refresh token does not raise: `ShopifyAPI.AuthToken.fetch/2` returns
  `{:error, :needs_reacquisition}` for it.
  """
  defexception message: "Auth token could not be refreshed", plug_status: 503
end

defmodule ShopifyAPI.TokenMigrationError do
  @moduledoc """
  Raised when a permanent-to-expiring token exchange succeeds at Shopify but the new pair
  cannot be stored, or Shopify returns an unusable one.

  Nothing is stored, so the permanent token is still in storage. For seven days after the
  exchange, presenting it again returns the same pair, unless that pair has been refreshed or the
  shop has acquired another token since. Under `:exchange_permanent`,
  `ShopifyAPI.AuthToken.fetch/2` does that on its next call. Past the window the shop has no
  working credential until its merchant reinstalls the app, so this raises rather than returning
  an error, and is worth alerting on.

  `ShopifyAPI.AuthRequest.migrate_offline_access_token/2` raises it. A failure *before* the
  exchange succeeds leaves the permanent token intact and returns `{:error, _}` instead, since
  that shop is safe to skip and retry.
  """
  defexception message: "Auth token migration could not be completed"
end
