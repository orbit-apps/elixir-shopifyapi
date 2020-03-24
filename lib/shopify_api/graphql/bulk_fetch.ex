defmodule ShopifyAPI.GraphQL.BulkFetch do
  alias ShopifyAPI.AuthToken

  @spec process(AuthToken.t(), String.t(), integer()) :: any()
  def process(%AuthToken{} = token, query, polling_rate \\ 100) do
    with :ok <- create(token, query),
         {:ok, url} <- poll_till_completed(token, polling_rate),
         {:ok, %{body: jsonl}} <- HTTPoison.get(url) do
      {:ok, parse_bulk_response(jsonl)}
    else
      error -> error
    end
  end

  defp create(token, query) do
    query_string = Jason.encode!(query)

    bulk_query = """
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

    resp = ShopifyAPI.graphql_request(token, bulk_query, 10)
    errors = get_in(resp, [:response, "bulkOperationRunQuery", "userErrors"])

    case Enum.empty?(errors) do
      true -> :ok
      false -> {:error, "Bulk Operation already in progress"}
    end
  end

  defp poll_till_completed(token, polling_rate) do
    Process.sleep(polling_rate)

    {:ok, %{response: %{"currentBulkOperation" => %{"status" => status} = response}}} =
      poll(token)

    case status do
      "COMPLETED" -> {:ok, Map.get(response, "url")}
      _ -> poll_till_completed(token, polling_rate)
    end
  end

  defp poll(%AuthToken{} = token) do
    poll_query = """
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

    ShopifyAPI.graphql_request(token, poll_query, 1)
  end

  defp parse_bulk_response(jsonl) do
    jsonl
    |> String.split("\n")
    |> Enum.drop(-1)
    |> Enum.map(&Jason.decode!/1)
  end
end
