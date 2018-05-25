defmodule ShopifyApi.Rest.Shop do
  @moduledoc """
  ShopifyApi REST API Shop resource
  """

  alias ShopifyApi.AuthToken
  alias ShopifyApi.Rest.Request

  @doc """
  Get a shop's configuration.

  ## Example

      iex> ShopifyApi.Rest.Shop.get(auth)
      {:ok, { "shop" => %{} }}
  """
  def get(%AuthToken{} = auth) do
    Request.get(auth, "shop.json")
  end
end
