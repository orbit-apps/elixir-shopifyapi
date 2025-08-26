defmodule ShopifyAPI.GraphQL do
  @moduledoc """
  Interface to Shopify's GraphQL Admin API.
  """

  require Logger

  alias ShopifyAPI.GraphQL.GraphQLQuery
  alias ShopifyAPI.GraphQL.GraphQLResponse
  alias ShopifyAPI.GraphQL.JSONParseError
  alias ShopifyAPI.GraphQL.Response
  alias ShopifyAPI.GraphQL.Telemetry
  alias ShopifyAPI.JSONSerializer

  @default_graphql_version "2020-10"

  @log_module __MODULE__ |> to_string() |> String.trim_leading("Elixir.")

  @type opts :: keyword()
  @type query_response ::
          {:ok, Response.t()}
          | {:error, JSONParseError.t() | HTTPoison.Response.t() | HTTPoison.Error.t()}

  @doc """
    Makes requests against Shopify GraphQL and returns a tuple containing
    a %Response struct with %{response, metadata, status_code}

    ## Example

      iex> query = "mutation metafieldDelete($input: MetafieldDeleteInput!){ metafieldDelete(input: $input) {deletedId userErrors {field message }}}",
      iex> variables = %{input: %{id: "gid://shopify/Metafield/9208558682200"}}
      iex> ShopifyAPI.GraphQL.query(auth, query, variables)
      {:ok, %Response{...}}
  """
  @spec query(ShopifyAPI.Scope.t(), String.t(), map(), list()) :: query_response()

  def query(auth_or_scope, query_string, variables \\ %{}, opts \\ [])

  def query(scope, query_string, variables, opts) do
    url = build_url(ShopifyAPI.Scopes.myshopify_domain(scope), opts)
    headers = build_headers(ShopifyAPI.Scopes.access_token(scope), opts)

    body =
      query_string
      |> build_body()
      |> insert_variables(variables)
      |> JSONSerializer.encode!()

    logged_request(scope, url, body, headers, opts)
  end

  @doc """
  Executes the given GrahpQLQuery for the given scope

  Telemetry events are sent to
    - [:shopify_api, :graphql_request, :start],
    - [:shopify_api, :graphql_request, :stop],
    - [:shopify_api, :graphql_request, :exception]

  ShopifyAPI.GraphQL.TelemetryLogger is provided for basic logging.
  """
  @spec execute(GraphQLQuery.t(), ShopifyAPI.Scope.t(), opts()) ::
          {:ok, GraphQLResponse.success_t()}
          | {:ok, GraphQLResponse.failure_t()}
          | {:error, Exception.t()}
  def execute(%GraphQLQuery{} = query, scope, opts \\ []) do
    url = build_url(ShopifyAPI.Scopes.myshopify_domain(scope), opts)
    headers = build_headers(ShopifyAPI.Scopes.access_token(scope), opts)
    body = JSONSerializer.encode!(%{query: query.query_string, variables: query.variables})
    metadata = %{scope: scope, query: query}

    :telemetry.span(
      [:shopify_api, :graphql_request],
      metadata,
      fn ->
        case Req.post(url, body: body, headers: headers) do
          {:ok, raw_response} ->
            response = GraphQLResponse.parse(raw_response, query)
            {{:ok, response}, Map.put(metadata, :response, response)}

          {:error, exception} ->
            {{:error, exception}, Map.put(metadata, :error, exception)}
        end
      end
    )
  end

  defp build_body(query_string), do: %{query: query_string}

  defp insert_variables(body, variables) do
    Map.put(body, :variables, variables)
  end

  def configured_version do
    config = Application.get_env(:shopify_api, ShopifyAPI.GraphQL, [])
    Keyword.get(config, :graphql_version, @default_graphql_version)
  end

  @doc """
  Returns rate limit info back from succesful responses.
  """
  def rate_limit_details({:ok, %Response{metadata: metadata}}) do
    actual_cost =
      metadata
      |> get_in(["cost", "actualQueryCost"])
      |> Kernel.trunc()

    currently_available =
      metadata
      |> get_in(["cost", "throttleStatus", "currentlyAvailable"])
      |> Kernel.trunc()

    maximum_available =
      metadata
      |> get_in(["cost", "throttleStatus", "maximumAvailable"])
      |> Kernel.trunc()

    rate_limit(actual_cost, currently_available, maximum_available)
  end

  def rate_limit_details(_) do
    rate_limit(nil, nil, nil)
  end

  defp rate_limit(actual_cost, currently_available, maximum_available) do
    %{
      actual_cost: actual_cost,
      currently_available: currently_available,
      maximum_available: maximum_available
    }
  end

  defp logged_request(scope_or_auth, url, body, headers, options) do
    {time, raw_response} = :timer.tc(HTTPoison, :post, [url, body, headers, options])

    response = Response.handle(raw_response)

    log_request(scope_or_auth, response, time)

    Telemetry.send(@log_module, scope_or_auth, url, time, response)

    response
  end

  defp log_request(%{app_name: app, shop_name: shop} = _token, response, time) do
    Logger.debug(fn ->
      status =
        case response do
          {:ok, %{status_code: status}} -> status
          {:error, reason} -> "error[#{inspect(reason)}]"
        end

      case rate_limit_details(response) do
        %{actual_cost: nil, currently_available: nil, maximum_available: nil} ->
          "#{@log_module} for #{shop}:#{app} received #{status} in #{div(time, 1_000)}ms"

        %{
          actual_cost: actual_cost,
          currently_available: currently_available,
          maximum_available: maximum_available
        } ->
          "#{@log_module} for #{shop}:#{app} received #{status} in #{div(time, 1_000)}ms [cost #{actual_cost} bucket #{currently_available}/#{maximum_available}]"
      end
    end)
  end

  defp log_request(scope, response, time) do
    log_request(
      %{
        app_name: ShopifyAPI.Scopes.app_name(scope),
        shop_name: ShopifyAPI.Scopes.myshopify_domain(scope)
      },
      response,
      time
    )
  end

  defp build_url(myshopify_domain, opts) do
    version = Keyword.get(opts, :version, configured_version())
    "#{ShopifyAPI.transport()}://#{myshopify_domain}/admin/api/#{version}/graphql.json"
  end

  defp build_headers(access_token, opts) do
    headers = [
      {"Content-Type", "application/json"},
      {"X-Shopify-Access-Token", access_token}
    ]

    if Keyword.get(opts, :debug, false) do
      [{"X-GraphQL-Cost-Include-Fields", "true"} | headers]
    else
      headers
    end
  end
end
