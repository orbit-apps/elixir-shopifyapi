defmodule ShopifyAPI.GraphQL.GraphQLResponse do
  @doc """
  Results of a GraphQLQuery
  """
  alias ShopifyAPI.GraphQL.GraphQLQuery

  defstruct query: nil,
            results: nil,
            raw: nil,
            errors: [],
            user_errors: [],
            metadata: nil,
            errors?: false

  @type t() :: t(any())

  @type t(results) :: success_t(results) | failure_t(results)

  @type success_t() :: success_t(any())
  @type success_t(results) :: %__MODULE__{
          results: results,
          query: GraphQLQuery.t(),
          raw: Req.Response.t(),
          errors?: true
        }

  @type failure_t() :: failure_t(any())
  @type failure_t(results) :: %__MODULE__{
          results: results | nil,
          query: GraphQLQuery.t(),
          raw: Req.Response.t(),
          errors?: false
        }

  @spec parse(Req.Response.t(), GraphQLQuery.t()) :: t()
  def parse(%Req.Response{} = raw, %GraphQLQuery{} = query) do
    %__MODULE__{query: query, raw: raw}
    |> set_results()
    |> set_errors()
    |> set_user_errors()
  end

  @spec resolve({:ok, success_t(type)}) :: {:ok, type} when type: any()
  @spec resolve({:ok, failure_t(type)}) :: {:error, failure_t(type)} when type: any()
  @spec resolve({:error, Exception.t()}) :: {:error, Exception.t()}
  def resolve({:ok, %__MODULE__{errors?: false, results: results}}), do: {:ok, results}
  def resolve({:ok, %__MODULE__{errors?: true} = response}), do: {:error, response}
  def resolve({:error, error}), do: {:error, error}

  defp set_results(
         %__MODULE__{raw: %Req.Response{body: %{"data" => data}, status: 200}} = graphql_response
       ) do
    if is_map(data) and Map.has_key?(data, graphql_response.query.name),
      do: %{graphql_response | results: get_in(data, graphql_response.query.path)},
      else: %{graphql_response | errors?: true}
  end

  defp set_results(%__MODULE__{raw: %Req.Response{body: _body}} = graphql_response),
    do: %{graphql_response | errors?: true}

  defp set_errors(
         %__MODULE__{raw: %Req.Response{body: %{"errors" => [_ | _] = errors}}} = graphql_response
       ),
       do: %{graphql_response | errors: errors, errors?: true}

  defp set_errors(%__MODULE__{raw: %Req.Response{body: _body}} = graphql_response),
    do: graphql_response

  defp set_user_errors(
         %__MODULE__{
           query: %{name: name},
           raw: %Req.Response{body: %{"data" => data}}
         } = graphql_response
       )
       when is_map(data) do
    case get_in(data, [name, "userErrors"]) do
      [_ | _] = user_errors -> %{graphql_response | user_errors: user_errors, errors?: true}
      _ -> graphql_response
    end
  end

  defp set_user_errors(%__MODULE__{raw: %Req.Response{body: _body}} = graphql_response),
    do: %{graphql_response | errors?: true}
end
