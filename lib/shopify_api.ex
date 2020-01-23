defmodule ShopifyAPI do
  alias ShopifyAPI.RateLimiting
  alias ShopifyAPI.Throttled

  def request(token, func), do: Throttled.request(func, token, RateLimiting.RESTTracker)

  @doc false
  # Accessor for API transport layer, defaults to `https://`.
  # Override in configuration to `http://` for testing using Bypass.
  @spec transport() :: String.t()
  def transport, do: Application.get_env(:shopify_api, :transport, "https://")
end
