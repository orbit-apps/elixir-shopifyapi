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

  This is the one unrecoverable failure in the token lifecycle. Unlike a refresh, the migration
  exchange has no replay: Shopify revokes the permanent token in the same step that issues the
  expiring pair, so once the exchange returns the new pair is the shop's only working
  credential. If it never reaches storage the shop is locked out until its merchant reinstalls
  the app, with nothing to fall back on — so this raises rather than returning an error, and is
  worth paging on.

  `ShopifyAPI.AuthRequest.migrate_offline_access_token/2` raises it. A failure *before* the
  exchange succeeds leaves the permanent token intact and returns `{:error, _}` instead, since
  that shop is safe to skip and retry.
  """
  defexception message: "Auth token migration could not be completed"
end
