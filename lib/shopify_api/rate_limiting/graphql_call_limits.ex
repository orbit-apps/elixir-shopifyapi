defmodule ShopifyAPI.RateLimiting.GraphQLCallLimits do
  alias ShopifyAPI.GraphQL
  alias ShopifyAPI.RateLimiting

  # Our internal point availability tracking sometimes differs from Shopify's
  # Adding this padding prevents requests being throttled unecessarily
  @estimate_padding 20

  @spec calculate_wait(
          {String.t(), integer(), DateTime.t()},
          ShopifyAPI.AuthToken.t(),
          integer(),
          DateTime.t()
        ) :: integer()
  def calculate_wait(
        {_key, points_available, time},
        token,
        estimated_cost,
        now \\ DateTime.utc_now()
      ) do
    seconds_elapsed = DateTime.diff(now, time)
    restore_rate_per_second = RateLimiting.GraphQL.restore_rate_per_second(token)
    estimated_restore_amount = restore_rate_per_second * seconds_elapsed

    diff = points_available + estimated_restore_amount - estimated_cost - @estimate_padding

    case diff > 0 do
      true -> 0
      false -> round(abs(diff) / restore_rate_per_second * 1000)
    end
  end

  @spec get_api_remaining_points(GraphQL.Response.t() | HTTPoison.Response.t()) :: integer()
  def get_api_remaining_points(%{
        metadata: %{"cost" => %{"throttleStatus" => %{"currentlyAvailable" => available}}}
      }) do
    available
  end

  # throttled queries return the HTTPoison.Response object
  def get_api_remaining_points(%{
        body: %{
          "extensions" => %{"cost" => %{"throttleStatus" => %{"currentlyAvailable" => available}}}
        }
      }) do
    available
  end

  def estimate_padding, do: @estimate_padding
end
