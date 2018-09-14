defmodule ShopifyAPI.REST.Shop do
  @moduledoc """
  ShopifyAPI REST API Shop resource
  """

  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST.Request

  @doc """
  Get a shop's configuration.

  ## Example

      iex> ShopifyAPI.REST.Shop.get(auth)
      {:ok, { "shop" => %{} }}
  """
  def get(%AuthToken{} = auth), do: Request.get(auth, "shop.json")
end
