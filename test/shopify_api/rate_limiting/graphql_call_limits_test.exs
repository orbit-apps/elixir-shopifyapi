defmodule ShopifyAPI.RateLimiting.GraphQLCallLimitsTest do
  use ExUnit.Case
  use ExUnitProperties

  alias ShopifyAPI.RateLimiting.GraphQLCallLimits

  setup do
    token = %ShopifyAPI.AuthToken{}
    now = ~U[2020-01-01 12:00:00.000000Z]
    %{now: now, token: token}
  end

  describe "calculate_wait/3" do
    property "larger points available than cost", %{now: now, token: token} do
      check all(
              int1 <- positive_integer(),
              int2 <- positive_integer(),
              estimated_cost = int1,
              points_available = int1 + int2,
              points_available > estimated_cost
            ) do
        assert GraphQLCallLimits.calculate_wait(
                 {"key", points_available + GraphQLCallLimits.estimate_padding(), now},
                 token,
                 estimated_cost,
                 now
               ) == 0
      end
    end

    property "larger cost than points available", %{now: now, token: token} do
      check all(
              int1 <- positive_integer(),
              int2 <- positive_integer(),
              points_available = int1,
              estimated_cost = int1 + int2,
              estimated_cost > points_available
            ) do
        assert GraphQLCallLimits.calculate_wait(
                 {"key", points_available, now},
                 token,
                 estimated_cost,
                 now
               ) > 0
      end
    end

    property "enough elapsed time to refill the bucket", %{now: now, token: token} do
      check all(
              int <- positive_integer(),
              date = DateTime.add(now, -int * 60 * 60)
            ) do
        assert GraphQLCallLimits.calculate_wait(
                 {"key", 0, date},
                 token,
                 500,
                 now
               ) == 0
      end
    end
  end
end
