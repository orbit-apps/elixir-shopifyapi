defmodule ShopifyAPI.GraphQL do
  @moduledoc """
  Interface to Shopify's GraphQL Admin API.
  """

  require Logger

  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.GraphQL.{JSONParseError, Response, Telemetry}
  alias ShopifyAPI.JSONSerializer

  @default_graphql_version "2019-10"

  @log_module __MODULE__ |> to_string() |> String.trim_leading("Elixir.")

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
  @spec query(AuthToken.t(), String.t(), map(), list()) :: query_response()
  def query(%AuthToken{} = auth, query_string, variables \\ %{}, opts \\ []) do
    url = build_url(auth, opts)
    headers = build_headers(auth, opts)

    body =
      query_string
      |> build_body()
      |> insert_variables(variables)
      |> JSONSerializer.encode!()

    logged_request(auth, url, body, headers, opts)
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
      |> case do
        nil -> nil
        val -> Kernel.trunc(val)
      end

    currently_available =
      metadata
      |> get_in(["cost", "throttleStatus", "currentlyAvailable"])
      |> case do
        nil -> nil
        val -> Kernel.trunc(val)
      end

    maximum_available =
      metadata
      |> get_in(["cost", "throttleStatus", "maximumAvailable"])
      |> case do
        nil -> nil
        val -> Kernel.trunc(val)
      end

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

  defp logged_request(auth, url, body, headers, options) do
    {time, raw_response} = :timer.tc(HTTPoison, :post, [url, body, headers, options])

    response = Response.handle(raw_response)

    log_request(auth, response, time)

    Telemetry.send(@log_module, auth, url, time, response)

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
          "#{@log_module} for #{shop}:#{app} received #{status} in #{div(time, 1_000)}ms [cost #{
            actual_cost
          } bucket #{currently_available}/#{maximum_available}]"
      end
    end)
  end

  defp build_url(%{shop_name: domain}, opts) do
    version = Keyword.get(opts, :version, configured_version())
    "#{ShopifyAPI.transport()}#{domain}/admin/api/#{version}/graphql.json"
  end

  defp build_headers(%{token: access_token}, opts) do
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
