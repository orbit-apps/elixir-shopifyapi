defmodule ShopifyAPI do
  alias ShopifyAPI.RateLimiting
  alias ShopifyAPI.Throttled

  @shopify_oauth_path "/admin/oauth/authorize"
  @oauth_default_options [use_user_tokens: false]
  @per_user_query_params ["grant_options[]": "per-user"]

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
  def transport, do: Application.get_env(:shopify_api, :transport, "https")

  @doc """
  Generates the OAuth URL for fetching the App<>Shop token or the UserToken
  depending on if you enable user_user_tokens.
  """
  @spec shopify_oauth_url(ShopifyAPI.App.t(), String.t(), list()) :: String.t()
  def shopify_oauth_url(app, domain, opts \\ [])
      when is_struct(app, ShopifyAPI.App) and is_binary(domain) and is_list(opts) do
    opts = Keyword.merge(@oauth_default_options, opts)
    user_token_query_params = opts |> Keyword.get(:use_user_tokens) |> per_user_query_params()
    query_params = oauth_query_params(app) ++ user_token_query_params

    %URI{scheme: "https", port: 443, host: domain, path: @shopify_oauth_path}
    |> URI.append_query(URI.encode_query(query_params))
    |> URI.to_string()
  end

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
