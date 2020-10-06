defmodule ShopifyAPI.Config do
  @moduledoc false

  def lookup(key), do: Application.get_env(:shopify_api, key)
  def lookup(key, subkey), do: Application.get_env(:shopify_api, key)[subkey]
end
