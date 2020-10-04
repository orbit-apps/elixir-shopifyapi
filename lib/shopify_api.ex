defmodule ShopifyAPI do
  alias ShopifyAPI.RateLimiting
  alias ShopifyAPI.Throttled

  @doc """
  A helper function for making throttled GraphQL requests.

  ## Example:

      iex> query = "mutation metafieldDelete($input: MetafieldDeleteInput!){ metafieldDelete(input: $input) {deletedId userErrors {field message }}}",
      iex> estimated_cost = 10
      iex> variables = %{input: %{id: "gid://shopify/Metafield/9208558682200"}}
      iex> options = [debug: true]
      iex> ShopifyAPI.graphql_request(auth_token, query, estimated_cost, variables, options)
      {:ok, %ShopifyAPI.GraphQL.Response{...}}
  """
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

  @spec bypass_host() :: String.t() | nil
  def bypass_host, do: Application.get_env(:shopify_api, :bypass_host)
end
