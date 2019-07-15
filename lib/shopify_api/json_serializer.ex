defmodule ShopifyAPI.JSONSerializer do
  @moduledoc """
  JSONSerializer provides a wrapper for JSON serialization which is configurable via the :shopify_api application configuration. It defaults to Poison for legacy support.


  Add the following to your configuration to override:
  ```
  config :shopify_api, json_library: Jason
  ```
  """

  def decode(json), do: json_library().decode(json)
  def encode(e), do: json_library().encode(e)
  def decode!(json), do: json_library().decode!(json)
  def encode!(e), do: json_library().encode!(e)
  defp json_library, do: Application.fetch_env!(:shopify_api, :json_library)
end
