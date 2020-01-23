defmodule ShopifyAPI.Availability.RESTTracker do
  @moduledoc """
  Handles Tracking of API throttling and when the API will be available for a request.
  """
  alias ShopifyAPI.Availability

  @behavior Availability.Tracker

  @name :shopify_api_rest_availability_tracker

  @impl Availability.Tracker
  def init, do: :ets.new(@name, [:named_table, :public])

  @impl Availability.Tracker
  def all, do: :ets.tab2list(@name)

  @impl Availability.Tracker
  def api_hit_limit(%ShopifyAPI.AuthToken{} = token, http_response, now \\ DateTime.utc_now()) do
    available_modifier =
      http_response
      |> Availability.RESTCallLimits.get_retry_after_header()
      |> Availability.RESTCallLimits.get_retry_after_milliseconds()

    set(token, 0, available_modifier, now)
  end

  @impl Availability.Tracker
  def update_api_call_limit(%ShopifyAPI.AuthToken{} = token, http_response) do
    http_response
    |> Availability.RESTCallLimits.limit_header_or_status_code()
    |> Availability.RESTCallLimits.get_api_remaining_calls()
    |> case do
      # Wait for a second to allow time for a bucket fill
      0 -> set(token, 0, 1_000)
      remaining -> set(token, remaining, 0)
    end
  end

  @impl Availability.Tracker
  def get(%ShopifyAPI.AuthToken{} = token, now \\ DateTime.utc_now()) do
    case :ets.lookup(@name, ShopifyAPI.AuthToken.create_key(token)) do
      [] ->
        {ShopifyAPI.request_bucket(token), 0}

      [{_token, count, time} | _] ->
        diff = time |> DateTime.diff(now, :millisecond) |> max(0)

        {count, diff}
    end
  end

  @impl Availability.Tracker
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
