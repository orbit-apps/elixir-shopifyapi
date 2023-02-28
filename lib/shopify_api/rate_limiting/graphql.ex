defmodule ShopifyAPI.RateLimiting.GraphQL do
  @plus_bucket 10_000
  @nonplus_bucket 1000

  @plus_restore_rate 500
  @nonplus_restore_rate 50

  @max_query_cost 1000

  def request_bucket(%{plus: true}), do: @plus_bucket
  def request_bucket(%{plus: false}), do: @nonplus_bucket

  def restore_rate_per_second(%{plus: true}), do: @plus_restore_rate
  def restore_rate_per_second(%{plus: false}), do: @nonplus_restore_rate

  def max_query_cost, do: @max_query_cost
end
