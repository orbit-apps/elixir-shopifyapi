defmodule ShopifyAPI.RateLimiting.REST do
  @plus_bucket 80
  @nonplus_bucket 40
  @plus_requests_per_second 4
  @nonplus_requests_per_second 2

  @over_limit_status_code 429

  def over_limit_status_code, do: @over_limit_status_code

  def request_bucket(%{plus: true}), do: @plus_bucket
  def request_bucket(%{plus: false}), do: @nonplus_bucket

  def requests_per_second(%{plus: true}), do: @plus_requests_per_second
  def requests_per_second(%{plus: false}), do: @nonplus_requests_per_second
end
