defmodule ShopifyAPI do
  alias ShopifyAPI.GraphQL.GraphQLQuery
  alias ShopifyAPI.GraphQL.GraphQLResponse
  alias ShopifyAPI.Throttled

  @shopify_admin_uri URI.new!("https://admin.shopify.com")
  @shopify_oauth_path "/admin/oauth/authorize"
  @oauth_default_options [use_user_tokens: false]
  @per_user_query_params ["grant_options[]": "per-user"]

  @doc """
  A helper function for making throttled GraphQL requests.

  Soft deprecated. Please use execute_graphql/3 or [GraphQLQuery](lib/shopify_api/graphql/graphql_query.ex) instead.

  ## Example:

      iex> query = "mutation metafieldDelete($input: MetafieldDeleteInput!){ metafieldDelete(input: $input) {deletedId userErrors {field message }}}",
      iex> estimated_cost = 10
      iex> variables = %{input: %{id: "gid://shopify/Metafield/9208558682200"}}
      iex> options = [debug: true]
      iex> ShopifyAPI.graphql_request(scope, query, estimated_cost, variables, options)
      {:ok, %ShopifyAPI.GraphQL.Response{...}}
  """
  @spec graphql_request(ShopifyAPI.Scope.t(), String.t(), integer(), map(), list()) ::
          ShopifyAPI.GraphQL.query_response()
  def graphql_request(scope, query, estimated_cost, variables \\ %{}, opts \\ []) do
    func = fn -> ShopifyAPI.GraphQL.query(scope, query, variables, opts) end
    Throttled.graphql_request(func, scope, estimated_cost)
  end

  @doc """
  Executes the given GrahpQLQuery for the given scope.

  See [GraphQLQuery](lib/shopify_api/graphql/graphql_query.ex) for details.
  """
  @spec execute_graphql(GraphQLQuery.t(), ShopifyAPI.Scope.t(), keyword()) ::
          {:ok, GraphQLResponse.t()} | {:error, Exception.t()}
  def execute_graphql(%GraphQLQuery{} = query, scope, opts \\ []),
    do: ShopifyAPI.GraphQL.execute(query, scope, opts)

  if function_exported?(ShopifyAPI.RateLiting.RESTTracker, :init, 0) do
    def request(token, func),
      do: ShopifyAPIThrottled.request(func, token, ShopifyAPI.RateLimiting.RESTTracker)
  end

  @doc false
  # Accessor for API transport layer, defaults to `https://`.
  # Override in configuration to `http://` for testing using Bypass.
  @spec transport() :: String.t()
  def transport, do: Application.get_env(:shopify_api, :transport, "https")

  @spec port() :: integer()
  def port do
    case transport() do
      "https" -> 443
      _ -> 80
    end
  end

  @doc """
  Generates the OAuth URL for fetching the App<>Shop token or the UserToken
  depending on if you enable user_user_tokens.
  """
  @spec shopify_oauth_url(ShopifyAPI.App.t(), String.t(), list()) :: String.t()
  def shopify_oauth_url(%ShopifyAPI.App{} = app, domain, opts \\ [])
      when is_binary(domain) and is_list(opts) do
    opts = Keyword.merge(@oauth_default_options, opts)
    user_token_query_params = opts |> Keyword.get(:use_user_tokens) |> per_user_query_params()
    query_params = oauth_query_params(app) ++ user_token_query_params

    domain
    |> ShopifyAPI.Shop.to_uri()
    # TODO use URI.append_path when we drop 1.14 support
    |> URI.merge(shopify_oauth_path())
    |> URI.append_query(URI.encode_query(query_params))
    |> URI.to_string()
  end

  @doc """
  Helper function to get Shopify's Admin URI.
  """
  @spec shopify_admin_uri() :: URI.t()
  def shopify_admin_uri, do: @shopify_admin_uri

  @spec shopify_oauth_path() :: String.t()
  def shopify_oauth_path, do: @shopify_oauth_path

  defp oauth_query_params(app) do
    [
      client_id: app.client_id,
      scope: app.scope,
      redirect_uri: app.auth_redirect_uri,
      state: app.nonce
    ]
  end

  defp per_user_query_params(true), do: @per_user_query_params
  defp per_user_query_params(_use_user_tokens), do: []
end
