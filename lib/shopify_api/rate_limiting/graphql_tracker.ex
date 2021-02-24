defmodule ShopifyAPI.RateLimiting.GraphQLTracker do
  @moduledoc """
  Handles Tracking of GraphQL API throttling and when the API will be available for a request.
  """

  @behaviour ShopifyAPI.RateLimiting.Tracker

  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.RateLimiting

  @name :shopify_api_graphql_availability_tracker

  @impl RateLimiting.Tracker
  def init, do: :ets.new(@name, [:named_table, :public])

  @impl RateLimiting.Tracker
  def all, do: :ets.tab2list(@name)

  def clear_all, do: :ets.delete_all_objects(@name)

  @impl RateLimiting.Tracker
  def api_hit_limit(%AuthToken{} = token, http_response, _now \\ DateTime.utc_now()) do
    update_api_call_limit(token, http_response)
  end

  @impl RateLimiting.Tracker
  def update_api_call_limit(%AuthToken{} = token, http_response) do
    remaining = RateLimiting.GraphQLCallLimits.get_api_remaining_points(http_response)

    set(token, remaining, 0)
  end

  @impl RateLimiting.Tracker
  def get(%ShopifyAPI.AuthToken{} = token, now \\ DateTime.utc_now(), estimated_cost) do
    case :ets.lookup(@name, ShopifyAPI.AuthToken.create_key(token)) do
      [] ->
        {RateLimiting.GraphQL.request_bucket(token), 0}

      [{_key, points_available, _time} | _] when points_available > estimated_cost ->
        {points_available, 0}

      [{_key, points_available, _time} = value | _] ->
        wait_in_milliseconds =
          RateLimiting.GraphQLCallLimits.calculate_wait(value, token, estimated_cost, now)

        {points_available, wait_in_milliseconds}
    end
  end

  @impl RateLimiting.Tracker
  def set(token, points_available, _, now \\ DateTime.utc_now())

  # Do nothing
  def set(_token, nil, _, _now), do: {0, 0}

  # Sets the current points available and time of the transaction (now)
  def set(%ShopifyAPI.AuthToken{} = token, points_available, _, now) do
    :ets.insert(@name, {ShopifyAPI.AuthToken.create_key(token), points_available, now})
    {points_available, 0}
  end
end
