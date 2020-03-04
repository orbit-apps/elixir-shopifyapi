defmodule ShopifyAPI do
  alias ShopifyAPI.RateLimiting
  alias ShopifyAPI.Throttled

  @spec graphql_request(ShopifyAPI.AuthToken.t(), String.t(), integer(), map(), list()) ::
          ShopifyAPI.GraphQL.query_response()
  def graphql_request(token, query, estimated_cost, variables \\ %{}, opts \\ []) do
    func = fn -> ShopifyAPI.GraphQL.query(token, query, variables, opts) end
    Throttled.graphql_request(func, token, estimated_cost)
  end

  def request(token, func), do: Throttled.request(func, token, RateLimiting.RESTTracker)

  @doc false
  # Accessor for API transport layer, defaults to `https://`.
  # Override in configuration to `http://` for testing using Bypass.
  @spec transport() :: String.t()
  def transport, do: Application.get_env(:shopify_api, :transport, "https://")
end
