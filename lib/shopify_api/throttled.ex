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

  See docs: https://help.shopify.com/en/api/reference/rest-admin-api-rate-limits
  """
  require Logger

  alias ShopifyAPI.AvailabilityTracker

  @request_max_tries 10

  def request(func, token, max_tries \\ @request_max_tries, depth \\ 1)

  def request(func, _token, max_tries, depth) when is_function(func) and max_tries == depth,
    do: func.()

  def request(func, token, max_tries, depth) when is_function(func) do
    over_limit_status_code = ShopifyAPI.over_limit_status_code()

    token
    |> AvailabilityTracker.get()
    |> make_request(func)
    |> case do
      # over request limit, back off and try again.
      {:ok, %{status_code: ^over_limit_status_code} = response} ->
        {available_count, remaining_modifier} = AvailabilityTracker.api_hit_limit(token, response)
        send_over_limit_telemetry(token, available_count, remaining_modifier, depth, response)
        request(func, token, max_tries, depth + 1)

      # successful request, update internal call limit
      {:ok, response} ->
        {available_count, remaining_modifier} =
          AvailabilityTracker.update_api_call_limit(token, response)

        send_within_limit_telemetry(token, available_count, remaining_modifier, depth, response)
        {:ok, response}

      error ->
        error
    end
  end

  def make_request(t, func, sleep_impl \\ &:timer.sleep/1)

  def make_request({_, wait}, func, sleep_impl) when is_integer(wait) and wait > 0 do
    sleep_impl.(wait)
    func.()
  end

  def make_request({_, _}, func, _), do: func.()

  ## Private Helpers

  defp send_over_limit_telemetry(
         token,
         available_count,
         wait_in_milliseconds,
         retry_depth,
         response
       ) do
    send_telemetry(
      token,
      available_count,
      wait_in_milliseconds,
      retry_depth,
      response,
      :over_limit
    )
  end

  defp send_within_limit_telemetry(
         token,
         available_count,
         wait_in_milliseconds,
         retry_depth,
         response
       ) do
    send_telemetry(
      token,
      available_count,
      wait_in_milliseconds,
      retry_depth,
      response,
      :within_limit
    )
  end

  defp send_telemetry(
         %{app_name: app, shop_name: shop} = _token,
         available_count,
         wait_in_milliseconds,
         retry_depth,
         %{status_code: status} = _response,
         type
       ) do
    :telemetry.execute(
      [:shopify_api, :throttling, type],
      %{
        remaining_calls: available_count,
        wait_in_milliseconds: wait_in_milliseconds,
        retry_depth: retry_depth
      },
      %{app: app, shop: shop, status_code: status}
    )
  end
end
