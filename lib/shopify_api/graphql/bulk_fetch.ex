defmodule ShopifyAPI.GraphQL.BulkFetch do
  alias ShopifyAPI.AuthToken

  @defaults [polling_rate: 100, max_poll_count: 100]
  @polling_timeout_message "BulkFetch timed out before completion"
  @polling_query """
  {
    currentBulkOperation {
      id
      status
      errorCode
      createdAt
      completedAt
      objectCount
      fileSize
      url
      partialDataUrl
    }
  }
  """

  @doc """
  ## Example
      iex> prod_id = 10
      iex> query = \"""
        {
          product(id: "gid://shopify/Product/\#{prod_id}") {
            collections(first: 1) {
              edges {
                node {
                  collection_id: id
                  }
                }
              }
            metafields(first: 1) {
              edges {
                node {
                  key
                  value
                  metafield_id: id
                }
              }
            }
          }
        }
      \"""
      iex> {:ok, token} = YourShopifyApp.ShopifyAPI.Shop.get_auth_token_from_slug("slug")
      iex> ShopifyAPI.GraphQL.BulkFetch.process!(token, query)
      [%{"collection_id" => "gid://shopify/Collection/xxx", ...}]
  """
  @spec process!(AuthToken.t(), String.t(), list() | integer()) :: list()
  def process!(token, query, polling_rate \\ 100)

  def process!(%AuthToken{} = token, query, polling_rate) when is_integer(polling_rate),
    do: process!(token, query, polling_rate: polling_rate)

  def process!(%AuthToken{} = token, query, opts) do
    opts = resolve_options(opts)
    {:ok, jsonl} = fetch_jsonl(token, query, opts[:polling_rate], opts[:max_poll_count])
    parse_bulk_response!(jsonl)
  end

  @doc """
  Like process/3 but returns a Streamable collection of decoded JSON or errors.

    ## Example
      iex> prod_id = 10
      iex> query = \"""
        {
          product(id: "gid://shopify/Product/\#{prod_id}") {
            collections(first: 1) {
              edges {
                node {
                  collection_id: id
                  }
                }
              }
            metafields(first: 1) {
              edges {
                node {
                  key
                  value
                  metafield_id: id
                }
              }
            }
          }
        }
      \"""
      iex> {:ok, token} = YourShopifyApp.ShopifyAPI.Shop.get_auth_token_from_slug("slug")
      iex> ShopifyAPI.GraphQL.BulkFetch.process_stream(token, query)
           |> Enum.map(fn {:ok, json} -> IO.puts(json) end)
  """
  @spec process_stream(AuthToken.t(), String.t(), list() | integer()) :: Enumerable.t()
  def process_stream(token, query, polling_rate \\ 100)

  def process_stream(%AuthToken{} = token, query, polling_rate)
      when is_integer(polling_rate),
      do: process_stream(token, query, polling_rate: polling_rate)

  def process_stream(%AuthToken{} = token, query, opts) do
    opts = resolve_options(opts)

    case fetch_jsonl(token, query, opts[:polling_rate], opts[:max_poll_count]) do
      {:ok, jsonl} ->
        jsonl
        |> String.splitter("\n", trim: true)
        |> Stream.map(&ShopifyAPI.JSONSerializer.decode/1)

      {:error, _} = error ->
        [error]
    end
  end

  @spec cancel(AuthToken.t(), String.t()) :: {:ok | :error, any()}
  def cancel(token, bulk_query_id) do
    query = """
    mutation {
      bulkOperationCancel(id: "#{bulk_query_id}") {
        bulkOperation {
          status
        }
        userErrors {
          field
          message
        }
      }
    }
    """

    ShopifyAPI.graphql_request(token, query, 1)
  end

  @doc false
  @spec fetch_jsonl(AuthToken.t(), String.t(), integer(), integer()) ::
          {:ok, String.t()} | {:error, any()}
  def fetch_jsonl(%AuthToken{} = token, query, polling_rate, max_poll_count) do
    with bulk_query <- bulk_query_string(query),
         {:ok, resp} <- ShopifyAPI.graphql_request(token, bulk_query, 10),
         :ok <- handle_errors(resp),
         bulk_query_id <- get_in(resp.response, ["bulkOperationRunQuery", "bulkOperation", "id"]),
         {:ok, url} <- poll_till_completed(token, bulk_query_id, polling_rate, max_poll_count),
         {:ok, jsonl} <- fetch_jsonl(url) do
      {:ok, jsonl}
    else
      error ->
        error
    end
  end

  defp fetch_jsonl(nil), do: {:ok, ""}

  defp fetch_jsonl(url) do
    url
    |> HTTPoison.get()
    |> case do
      {:ok, %{body: jsonl}} -> {:ok, jsonl}
      error -> error
    end
  end

  defp resolve_options(opts), do: Keyword.merge(@defaults, opts, fn _k, _dv, nv -> nv end)

  defp handle_errors(resp) do
    errors = get_in(resp.response, ["bulkOperationRunQuery", "userErrors"])

    case Enum.empty?(errors) do
      true -> :ok
      false -> {:error, fetch_first_error(errors)}
    end
  end

  defp bulk_query_string(query) do
    query_string = ShopifyAPI.JSONSerializer.encode!(query)

    """
    mutation {
      bulkOperationRunQuery(
        query: #{query_string}
      ) {
        bulkOperation {
          id
          status
        }
        userErrors {
          field
          message
        }
      }
    }
    """
  end

  defp fetch_first_error(errors) do
    errors
    |> List.first()
    |> Map.get("message")
  end

  defp poll_till_completed(token, bulk_query_id, polling_rate, max_poll_count, depth \\ 0)

  defp poll_till_completed(token, bulk_query_id, _, max_poll_count, depth)
       when max_poll_count == depth do
    cancel(token, bulk_query_id)
    {:error, @polling_timeout_message}
  end

  defp poll_till_completed(token, bulk_query_id, polling_rate, max_poll_count, depth) do
    Process.sleep(polling_rate)

    token
    |> ShopifyAPI.graphql_request(@polling_query, 1)
    |> case do
      {:ok, %{response: %{"currentBulkOperation" => %{"status" => "COMPLETED"} = response}}} ->
        {:ok, Map.get(response, "url")}

      _ ->
        poll_till_completed(token, bulk_query_id, polling_rate, max_poll_count, depth + 1)
    end
  end

  defp parse_bulk_response!(""), do: []

  defp parse_bulk_response!(jsonl) do
    jsonl
    |> String.split("\n", trim: true)
    |> Enum.map(&ShopifyAPI.JSONSerializer.decode!/1)
  end
end
