defmodule ShopifyAPI do
  alias ShopifyAPI.RateLimiting
  alias ShopifyAPI.Throttled

  @spec graphql_request(ShopifyAPI.AuthToken.t(), function(), integer()) ::
          ShopifyAPI.GraphQL.query_response()
  def graphql_request(token, func, estimated_cost),
    do: Throttled.graphql_request(func, token, estimated_cost)

  def request(token, func), do: Throttled.request(func, token, RateLimiting.RESTTracker)

  @doc false
  # Accessor for API transport layer, defaults to `https://`.
  # Override in configuration to `http://` for testing using Bypass.
  @spec transport() :: String.t()
  def transport, do: Application.get_env(:shopify_api, :transport, "https://")
end
