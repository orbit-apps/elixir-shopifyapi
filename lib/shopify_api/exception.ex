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
