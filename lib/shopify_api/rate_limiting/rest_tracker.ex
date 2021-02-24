defmodule ShopifyAPI.RateLimiting.RESTTracker do
  @moduledoc """
  Handles Tracking of API throttling and when the API will be available for a request.
  """

  @behaviour ShopifyAPI.RateLimiting.Tracker

  alias ShopifyAPI.RateLimiting

  @name :shopify_api_rest_availability_tracker

  @impl RateLimiting.Tracker
  def init, do: :ets.new(@name, [:named_table, :public])

  @impl RateLimiting.Tracker
  def all, do: :ets.tab2list(@name)

  @impl RateLimiting.Tracker
  def api_hit_limit(%ShopifyAPI.AuthToken{} = token, http_response, now \\ DateTime.utc_now()) do
    available_modifier =
      http_response
      |> RateLimiting.RESTCallLimits.get_retry_after_header()
      |> RateLimiting.RESTCallLimits.get_retry_after_milliseconds()

    set(token, 0, available_modifier, now)
  end

  @impl RateLimiting.Tracker
  def update_api_call_limit(%ShopifyAPI.AuthToken{} = token, http_response) do
    http_response
    |> RateLimiting.RESTCallLimits.limit_header_or_status_code()
    |> RateLimiting.RESTCallLimits.get_api_remaining_calls()
    |> case do
      # Wait for a second to allow time for a bucket fill
      0 -> set(token, 0, 1_000)
      remaining -> set(token, remaining, 0)
    end
  end

  @impl RateLimiting.Tracker
  def get(%ShopifyAPI.AuthToken{} = token, now \\ DateTime.utc_now(), _estimated_cost) do
    case :ets.lookup(@name, ShopifyAPI.AuthToken.create_key(token)) do
      [] ->
        {RateLimiting.REST.request_bucket(token), 0}

      [{_key, count, time} | _] ->
        diff = time |> DateTime.diff(now, :millisecond) |> max(0)

        {count, diff}
    end
  end

  @impl RateLimiting.Tracker
  def set(token, available_count, availability_delay, now \\ DateTime.utc_now())

  # Do nothing
  def set(_token, nil, _availability_delay, _now), do: {0, 0}

  # Sets the current availability count and when the API will be available
  def set(
        %ShopifyAPI.AuthToken{} = token,
        available_count,
        availability_delay,
        now
      ) do
    available_at = DateTime.add(now, availability_delay, :millisecond)

    :ets.insert(@name, {ShopifyAPI.AuthToken.create_key(token), available_count, available_at})
    {available_count, availability_delay}
  end
end
