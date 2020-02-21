defmodule ShopifyAPI.Availability.GraphQLTracker do
  @moduledoc """
  Handles Tracking of API throttling and when the API will be available for a request.
  """

  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.CallLimits

  @behavior ShopifyAPI.Availability.Tracker
end
