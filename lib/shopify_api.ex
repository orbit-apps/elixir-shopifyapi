defmodule ShopifyAPI do
  @plus_bucket 80
  @nonplus_bucket 40
  @plus_requests_per_second 4
  @nonplus_requests_per_second 2

  @over_limit_status_code 429

  # def request(token, func), do: Throttled.request(func, token)

  def over_limit_status_code, do: @over_limit_status_code

  def request_bucket(%{plus: true}), do: @plus_bucket
  def request_bucket(%{plus: false}), do: @nonplus_bucket

  def requests_per_second(%{plus: true}), do: @plus_requests_per_second
  def requests_per_second(%{plus: false}), do: @nonplus_requests_per_second

  @doc false
  # Accessor for API transport layer, defaults to `https://`.
  # Override in configuration to `http://` for testing using Bypass.
  @spec transport() :: String.t()
  def transport, do: Application.get_env(:shopify_api, :transport, "https://")
end
