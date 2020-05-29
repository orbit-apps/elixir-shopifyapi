defmodule ShopifyAPI.Bulk.Cancel do
  require Logger

  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.Bulk.Query

  @polling_timeout_message "BulkFetch timed out before completion"
  @auto_cancel_sleep_duration 1_000

  @spec perform(boolean(), AuthToken.t(), String.t()) :: {:ok | :error, any()}
  def perform(false, _, _), do: {:error, @polling_timeout_message}

  def perform(true, token, bid) do
    token
    |> Query.cancel(bid)
    |> poll(token, bid)
    |> case do
      {:ok, _} = value -> value
      _ -> {:error, @polling_timeout_message}
    end
  end

  defp poll(resp, token, bid, max_poll \\ 500, depth \\ 0)

  # response from cancel/1
  defp poll({:ok, %{"bulkOperation" => %{"status" => "CANCELED"}}}, _token, _bid, _, _), do: true

  defp poll({:ok, %{"bulkOperation" => %{"status" => "COMPLETED"}}}, token, _bid, _, _) do
    case Query.status(token) do
      {:ok, %{"status" => "COMPLETED", "url" => url}} ->
        {:ok, url}

      _ ->
        {:error, "#{__MODULE__} got an error while fetching status after getting COMPLETED"}
    end
  end

  defp poll(_, token, _bid, max_poll, depth) when max_poll == depth do
    Logger.warn("#{__MODULE__} Cancel polling timed out for #{token.shop_name}")
    {:error, :cancelation_timedout}
  end

  defp poll(_, token, bid, max_poll, depth) do
    Process.sleep(@auto_cancel_sleep_duration)

    token
    |> Query.cancel(bid)
    |> poll(token, bid, max_poll, depth + 1)
  end
end
