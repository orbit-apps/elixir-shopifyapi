defmodule ShopifyAPI.Bulk.Query do
  require Logger

  alias ShopifyAPI.AuthToken

  @type status_response :: map()

  @polling_timeout_message "BulkFetch timed out before completion"
  @auto_cancel_sleep_duration 200
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

    # {
    #   "data": {
    #     "bulkOperationCancel": {
    #       "bulkOperation": {
    #         "status": "CANCELING"
    #       },
    #       "userErrors": []
    #     }
    #   },
    #   "extensions": {
    #     "cost": {
    #       "requestedQueryCost": 10,
    #       "actualQueryCost": 10,
    #       "throttleStatus": {
    #         "maximumAvailable": 1000.0,
    #         "currentlyAvailable": 990,
    #         "restoreRate": 50.0
    #       }
    #     }
    #   }
    # }

    case ShopifyAPI.graphql_request(token, query, 1) do
      {:ok, %{response: %{"bulkOperationCancel" => resp}}} -> {:ok, resp}
      error -> error
    end
  end

  @spec exec(AuthToken.t(), String.t(), list()) :: {:ok, String.t()} | {:error, any()}
  def exec(%AuthToken{} = token, query, opts) do
    with bulk_query <- bulk_query_string(query),
         {:ok, resp} <- ShopifyAPI.graphql_request(token, bulk_query, 10),
         :ok <- handle_errors(resp),
         bulk_query_id <- get_in(resp.response, ["bulkOperationRunQuery", "bulkOperation", "id"]),
         {:ok, url} <- poll(token, bulk_query_id, opts[:polling_rate], opts[:max_poll_count]) do
      {:ok, url}
    else
      {:error, :timeout, bulk_id} ->
        maybe_cancel(opts[:auto_cancel], token, bulk_id)

      error ->
        error
    end
  end

  # Shopify returns a single newline which gets stripped and we are left with garbage,
  # handle it nicely here.
  def fetch(nil), do: {:ok, ""}

  def fetch({:error, _} = error), do: error
  def fetch({:ok, url}), do: fetch(url)

  def fetch(url) when is_binary(url) do
    url
    |> HTTPoison.get()
    |> case do
      {:ok, %{body: jsonl}} -> {:ok, jsonl}
      error -> error
    end
  end

  def parse_response!(""), do: []
  def parse_response!({:ok, jsonl}), do: parse_response!(jsonl)
  def parse_response!({:error, msg}), do: raise(ShopifyAPI.Bulk.QueryError, msg)

  def parse_response!(jsonl) when is_binary(jsonl) do
    jsonl
    |> String.split("\n", trim: true)
    |> Enum.map(&ShopifyAPI.JSONSerializer.decode!/1)
  end

  @spec status(AuthToken.t()) :: {:ok, status_response()} | {:error, any()}
  def status(%AuthToken{} = token) do
    token
    |> ShopifyAPI.graphql_request(@polling_query, 1)
    |> case do
      {:ok, %{response: %{"currentBulkOperation" => response}}} ->
        {:ok, response}

      {:error, _} = error ->
        error
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

  defp poll(token, bulk_query_id, polling_rate, max_poll, depth \\ 0)

  defp poll(_token, bulk_query_id, _, max_poll, depth) when max_poll == depth,
    do: {:error, :timeout, bulk_query_id}

  defp poll(token, bulk_query_id, polling_rate, max_poll, depth) do
    Process.sleep(polling_rate)

    case status(token) do
      {:ok, %{"status" => "COMPLETED", "url" => url} = _response} -> {:ok, url}
      _ -> poll(token, bulk_query_id, polling_rate, max_poll, depth + 1)
    end
  end

  defp maybe_cancel(false, _, _), do: {:error, @polling_timeout_message}
  defp maybe_cancel(true, token, bid) do
    token
    |> cancel(bid)
    |> poll_till_cancel(token)
    |> case do
      {:ok, _} = value -> value
      _ -> {:error, @polling_timeout_message}
    end
  end

  defp poll_till_cancel(resp, token, max_poll \\ 300, depth \\ 0)

  # response from cancel/1
  defp poll_till_cancel({:ok, %{"bulkOperation" => %{"status" => "CANCELED"}}}, _token, _, _),
    do: true

  # response from status/1
  defp poll_till_cancel({:ok, %{"status" => "CANCELED"}}, _token, _, _), do: true

  # Sometimes operations complete before they are able to cancelled
  defp poll_till_cancel({:ok, %{"status" => "COMPLETED", "url" => url}}, _token, _, _), do: {:ok, url}

  defp poll_till_cancel(_, token, max_poll, depth) when max_poll == depth do
    Logger.warn("#{__MODULE__} Cancel polling timed out for #{token.shop_name}")
    {:error, :cancelation_timedout}
  end

  defp poll_till_cancel(_, token, max_poll, depth) do
    Process.sleep(@auto_cancel_sleep_duration)

    token
    |> status()
    |> poll_till_cancel(token, max_poll, depth + 1)
  end
end
