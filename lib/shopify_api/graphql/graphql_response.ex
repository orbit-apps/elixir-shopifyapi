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

  @type t :: %__MODULE__{
          query: GraphQLQuery.t(),
          raw: Req.Response.t(),
          errors?: boolean()
        }

  def parse(%Req.Response{} = raw, %GraphQLQuery{} = query) do
    %__MODULE__{query: query, raw: raw}
    |> set_results()
    |> set_errors()
    |> set_user_errors()
  end

  def resolve({:ok, %__MODULE__{errors?: false, results: results}}), do: {:ok, results}
  def resolve({:ok, %__MODULE__{errors?: true} = response}), do: {:error, response}
  def resolve({:error, error}), do: {:error, error}

  defp set_results(%__MODULE__{raw: %Req.Response{body: %{"data" => data}}} = graphql_response),
    do: %{graphql_response | results: get_in(data, graphql_response.query.path)}

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
           raw: %Req.Response{body: body}
         } = graphql_response
       )
       when is_map(body) do
    case get_in(body, ["data", name, "userErrors"]) do
      [_ | _] = user_errors -> %{graphql_response | user_errors: user_errors, errors?: true}
      _ -> graphql_response
    end
  end

  defp set_user_errors(%__MODULE__{raw: %Req.Response{body: _body}} = graphql_response),
    do: %{graphql_response | errors?: true}
end
