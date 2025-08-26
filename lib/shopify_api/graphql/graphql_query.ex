defmodule ShopifyAPI.GraphQL.GraphQLQuery do
  @moduledoc """
  A quiery builder for Shopify GraphQL

  The query is made with a scope that implements `ShopifyAPI.Scope`

  In your query file `use ShopifyAPI.GraphQL.GraphQLQuery` and implement
    - query_string/1
    - name/1 - matches the root name of the query
    - path/1 - a list of access functions for the returning data.

  ```elixir
    defmodule MyApp.Shopify.Query.ThemeList do
      use ShopifyAPI.GraphQL.GraphQLQuery

      @theme_list ~S[
        query {
          themes(first: 20) {
            edges {
              node {
                name
                id
                role
              }
            }
          }
        }
      ]

      def query_string, do: @theme_list
      def name, do: "themes"
      def path, do: ["edges", Access.all(), "node"]
    end
  ```

  ```elixir
    def list_themes(%Model.Scope{} = scope, variables) do
      Query.ThemeList.query()
      |> Query.ThemeList.assigns(variables)
      |> Query.ThemeList.execute(scope)
      |> GraphQLResponse.resolve()
    end
  ```
  """

  defstruct [:name, :query_string, :variables, :path]

  alias ShopifyAPI.GraphQL.GraphQLResponse

  @type t :: %__MODULE__{
          name: String.t(),
          query_string: String.t(),
          variables: map(),
          path: [term()]
        }

  @callback query_string() :: String.t()
  @callback name() :: String.t()
  @callback path() :: list()

  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)

      @type t :: unquote(__MODULE__).t()

      @spec query :: t()
      def query do
        query_string()
        |> unquote(__MODULE__).build(name())
        |> append_path(path())
      end

      defdelegate assign(query, key, value), to: unquote(__MODULE__)
      defdelegate assigns(query, map), to: unquote(__MODULE__)
      defdelegate append_path(query, access), to: unquote(__MODULE__)
      defdelegate execute(query, scope), to: unquote(__MODULE__)
    end
  end

  def build(query_string, name) do
    %__MODULE__{
      name: name,
      query_string: query_string,
      variables: %{},
      path: [name]
    }
  end

  @spec append_path(t(), any()) :: t()
  def append_path(%__MODULE__{} = query, access),
    do: %{query | path: query.path ++ List.wrap(access)}

  @spec assign(t(), any(), any()) :: t()
  def assign(%__MODULE__{} = query, key, value), do: assigns(query, %{key => value})

  @spec assigns(t(), map()) :: t()
  def assigns(%__MODULE__{} = query, map) when is_map(map),
    do: %{query | variables: Map.merge(query.variables, map)}

  @spec execute(t(), ShopifyAPI.Scope.t()) ::
          {:ok, GraphQLResponse.success_t()}
          | {:ok, GraphQLResponse.failure_t()}
          | {:error, Exception.t()}
  def execute(query, scope), do: ShopifyAPI.GraphQL.execute(query, scope)

  @doc """
  Returns a function that accesses the key/value paths as a map.

  ## Examples
    iex> get_in(
    ...>   %{"nodes" => [
    ...>      %{"filename" => "file1", "body" => %{"content" => "file1 content"}},
    ...>      %{"filename" => "file2", "body" => %{"content" => "file2 content"}}
    ...>   ]},
    ...>   ["nodes", GraphQLQuery.access_map(["filename"], ["body", "content"])]
    ...> )
    %{"file1" => "file1 content", "file2" => "file2 content"}
  """
  @spec access_map(term, term) :: Access.access_fun(data :: map, current_value :: term)
  def access_map(key, value) do
    fn
      :get, data, next when is_list(data) ->
        next.(Map.new(data, &{get_in(&1, key), get_in(&1, value)}))

      :get, data, next ->
        next.(%{get_in(data, key) => get_in(data, value)})

      :get_and_update, _data, _next ->
        raise "access_map not implemented for get_and_update"
    end
  end
end
