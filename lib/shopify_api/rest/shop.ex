defmodule ShopifyAPI.REST.Shop do
  @moduledoc """
  ShopifyAPI REST API Shop resource
  """

  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST

  @doc """
  Get a shop's configuration.

  ## Example

      iex> ShopifyAPI.REST.Shop.get(auth)
      {:ok, %{} = shop}
  """
  def get(%AuthToken{} = auth, params \\ [], options \\ []),
    do: REST.get(auth, "shop.json", params, Keyword.merge([pagination: :none], options))
end
