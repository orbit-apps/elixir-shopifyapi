defmodule ShopifyAPI.RateLimiting.GraphQLTrackerTest do
  use ExUnit.Case

  alias ShopifyAPI.RateLimiting.{GraphQL, GraphQLTracker}

  setup do
    GraphQLTracker.clear_all()
    token = %ShopifyAPI.AuthToken{}
    now = ~U[2020-01-01 12:00:00.000000Z]

    %{now: now, token: token}
  end

  describe "update_api_call_limit" do
    test "returns available from GraphQL.Response", %{token: token} do
      available = 250

      response = %ShopifyAPI.GraphQL.Response{
        metadata: %{"cost" => %{"throttleStatus" => %{"currentlyAvailable" => available}}}
      }

      assert {^available, 0} = GraphQLTracker.update_api_call_limit(token, response)
    end

    test "returns available from HTTPoison.Response", %{token: token} do
      available = 250

      response = %HTTPoison.Response{
        body: %{
          "extensions" => %{"cost" => %{"throttleStatus" => %{"currentlyAvailable" => available}}}
        }
      }

      assert {^available, 0} = GraphQLTracker.update_api_call_limit(token, response)
    end
  end

  describe "get/3" do
    test "handles get without having set", %{now: now, token: token} do
      default = GraphQL.request_bucket(token)
      assert {^default, 0} = GraphQLTracker.get(token, now, 1)
    end

    test "returns set points available", %{now: now, token: token} do
      points = 500
      GraphQLTracker.set(token, points, now)
      assert {^points, 0} = GraphQLTracker.get(token, now, 1)
    end

    test "returns a wait when estimate exceeds available points", %{now: now, token: token} do
      GraphQLTracker.set(token, 500, now)
      {_, wait} = GraphQLTracker.get(token, now, 600)
      assert wait > 0
    end
  end
end
