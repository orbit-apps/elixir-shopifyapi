defmodule ShopifyAPI.JSONSerializer do
  @moduledoc """
  Abstraction point allowing for use of a custom JSON serializer, if your app requires it.
  By default `shopify_api` uses the popular `jason`, you can override this in your config:

      # use Poison to encode/decode JSON
      config :shopify_api, :json_library, Poison

  After doing so, you must make sure to re-compile the `shopify_api` dependency:

      $ mix deps.compile --force shopify_api
  """

  @codec Application.compile_env(:shopify_api, :json_library, Jason)

  defdelegate encode(json_str), to: @codec
  defdelegate decode(json_str), to: @codec

  defdelegate encode!(json_str), to: @codec
  defdelegate decode!(json_str), to: @codec
end
