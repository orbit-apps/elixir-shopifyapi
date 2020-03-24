defmodule ShopifyAPI.GraphQL.BulkFetch do
  alias ShopifyAPI.AuthToken

  @max_poll_count 100
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
      {:ok,
        [%{"collection_id" => "gid://shopify/Collection/xxx", ...}],
      }
  """
  @spec process!(AuthToken.t(), String.t(), integer()) :: {:ok, list()} | {:error, any()}
  def process!(%AuthToken{} = token, query, polling_rate \\ 100) do
    case fetch_jsonl(token, query, polling_rate) do
      {:ok, jsonl} -> {:ok, parse_bulk_response!(jsonl)}
      {:error, _} = error -> error
    end
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
      iex> func = fn {:ok, json} -> IO.puts(json) end # Warning we are not handling error conditions here.
      iex> ShopifyAPI.GraphQL.BulkFetch.process_stream(token, query, func)
  """
  @spec process_stream(AuthToken.t(), String.t(), integer()) :: Enumerable.t()
  def process_stream(%AuthToken{} = token, query, polling_rate \\ 100) do
    case fetch_jsonl(token, query, polling_rate) do
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
  @spec fetch_jsonl(AuthToken.t(), String.t(), integer()) :: {:ok, String.t()} | {:error, any()}
  def fetch_jsonl(%AuthToken{} = token, query, polling_rate) do
    with bulk_query <- bulk_query_string(query),
         {:ok, resp} <- ShopifyAPI.graphql_request(token, bulk_query, 10),
         :ok <- handle_errors(resp),
         bulk_query_id <- get_in(resp.response, ["bulkOperationRunQuery", "bulkOperation", "id"]),
         {:ok, url} <- poll_till_completed(token, bulk_query_id, polling_rate),
         {:ok, %{body: jsonl}} <- HTTPoison.get(url) do
      {:ok, jsonl}
    else
      error -> error
    end
  end

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

  defp poll_till_completed(token, bulk_query_id, polling_rate, depth \\ 0)

  defp poll_till_completed(token, bulk_query_id, _, @max_poll_count) do
    cancel(token, bulk_query_id)
    {:error, @polling_timeout_message}
  end

  defp poll_till_completed(token, bulk_query_id, polling_rate, depth) do
    Process.sleep(polling_rate)

    token
    |> ShopifyAPI.graphql_request(@polling_query, 1)
    |> case do
      {:ok, %{response: %{"currentBulkOperation" => %{"status" => "COMPLETED"} = response}}} ->
        {:ok, Map.get(response, "url")}

      _ ->
        poll_till_completed(token, bulk_query_id, polling_rate, depth + 1)
    end
  end

  defp parse_bulk_response!(jsonl) do
    jsonl
    |> String.split("\n", trim: true)
    |> Enum.map(&ShopifyAPI.JSONSerializer.decode!/1)
  end
end
