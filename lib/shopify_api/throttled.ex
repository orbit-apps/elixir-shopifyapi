defmodule ShopifyAPI.Throttled do
  @moduledoc """
  A wrapper for requests against Shopify's API, implementing request throttling.

  For more information on Shopify's REST API Rate Limiting:
  https://help.shopify.com/en/api/reference/rest-admin-api-rate-limits

  Request "buckets" are identified based on the provided `AuthToken`. An ets
  table is checked before making a request, seeing if additional requests are
  allowed. If not, the client will sleep before attempting the request.

  Upon receiving a HTTP response, the number of allowed requests is
  extracted from response headers and inserted into the ets table.

  If Shopify returns the `429 Too Many Requests` status code for a request, it
  will be retried after a delay and re-check of the ets table, to a maximum of
  10 total attempts (this is configurable).
  """
  require Logger

  alias ShopifyAPI.ThrottleServer

  @request_max_tries 10

  def request(func, token, max_tries \\ @request_max_tries, depth \\ 1)

  def request(func, _token, max_tries, depth) when is_function(func) and max_tries == depth,
    do: func.()

  def request(func, token, max_tries, depth) when is_function(func) do
    over_limit_status_code = ShopifyAPI.over_limit_status_code()

    token
    |> ThrottleServer.get()
    |> make_request(func, ShopifyAPI.requests_per_second(token))
    |> case do
      # over request limit, back off and try again.
      {:ok, %{status_code: ^over_limit_status_code}} ->
        request(func, token, max_tries, depth + 1)

      # successful request, update internal call limit
      {:ok, response} ->
        ThrottleServer.update_api_call_limit(response, token)
        {:ok, response}

      error ->
        error
    end
  end

  def make_request(t, func, req_sec, sleep_impl \\ &:timer.sleep/1)

  # No limit found in the store, make a request
  def make_request({_, last_check}, func, _, _) when last_check == :no_time, do: func.()

  # Haven't hit our limit yet, make a request
  def make_request({limit, _}, func, _, _) when limit > 0, do: func.()

  def make_request({_, last_check}, func, req_sec, sleep_impl) do
    case last_check_is_stale?(last_check, req_sec) do
      :lt ->
        func.()

      _ ->
        sleep_impl.(round(1_000 / req_sec))
        func.()
    end
  end

  defp last_check_is_stale?(last_check, req_sec) do
    last_check
    |> NaiveDateTime.add(round(1_000 / req_sec), :millisecond)
    |> NaiveDateTime.compare(NaiveDateTime.utc_now())
  end
end
