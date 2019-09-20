defmodule ShopifyAPI.AvailabilityTracker do
  @moduledoc """
  Handles Tracking of API throttling and when the API will be available for a request.
  """
  alias HTTPoison.Response, as: HTTPResponse
  alias ShopifyAPI.{AuthToken, CallLimit}

  @type available_count :: integer()
  @type availability_delay :: integer()
  @type t :: {available_count(), availability_delay()}

  @name :shopify_api_availability_tracker

  @spec init() :: any()
  def init, do: :ets.new(@name, [:named_table, :public])

  @spec all() :: list()
  def all, do: :ets.tab2list(@name)

  @spec api_hit_limit(AuthToken.t(), HTTPResponse.t(), DateTime.t()) :: t()
  def api_hit_limit(%AuthToken{} = token, http_response, now \\ DateTime.utc_now()) do
    available_modifier =
      http_response
      |> CallLimit.get_retry_after_header()
      |> CallLimit.get_retry_after_milliseconds()

    set(token, 0, available_modifier, now)
  end

  @spec update_api_call_limit(AuthToken.t(), HTTPResponse.t()) :: t()
  def update_api_call_limit(%AuthToken{} = token, http_response) do
    http_response
    |> CallLimit.limit_header_or_status_code()
    |> CallLimit.get_api_remaining_calls()
    |> case do
      # Wait for a second to allow time for a bucket fill
      0 -> set(token, 0, 1_000)
      remaining -> set(token, remaining, 0)
    end
  end

  @spec get(AuthToken.t(), DateTime.t()) :: t()
  def get(%AuthToken{} = token, now \\ DateTime.utc_now()) do
    case :ets.lookup(@name, AuthToken.create_key(token)) do
      [] ->
        {ShopifyAPI.request_bucket(token), 0}

      [{_token, count, time} | _] ->
        diff = time |> DateTime.diff(now, :millisecond) |> max(0)

        {count, diff}
    end
  end

  @spec set(AuthToken.t(), available_count(), availability_delay(), DateTime.t()) ::
          t()
  def set(token, available_count, availability_delay, now \\ DateTime.utc_now())

  # Do nothing
  def set(_token, nil, _availability_delay, _now), do: {0, 0}

  # Sets the current availability count and when the API will be available
  def set(
        %AuthToken{} = token,
        available_count,
        availability_delay,
        now
      ) do
    available_at = DateTime.add(now, availability_delay, :millisecond)

    :ets.insert(@name, {AuthToken.create_key(token), available_count, available_at})
    {available_count, availability_delay}
  end
end
