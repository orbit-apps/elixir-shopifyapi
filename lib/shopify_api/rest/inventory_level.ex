defmodule ShopifyAPI.REST.InventoryLevel do
  @moduledoc """
  ShopifyAPI REST API InventoryLevel resource
  """
  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST.Request

  @doc """
  Return a list of inventory levels.

  ## Example

      iex> ShopifyAPI.REST.InventoryLevel.all(auth)
      {:ok, { "inventory_level" => [] }}
  """
  def all(%AuthToken{} = auth) do
    Request.get(auth, "inventory_levels.json")
  end

  @doc """
  Delete an inventory level of an inventory item at a location.

  ## Example

      iex> ShopifyAPI.REST.InventoryLevel.delete(auth, integer, integer)
      {:ok, 200 }}
  """
  def delete(%AuthToken{} = auth, inventory_item_id, location_id) do
    Request.delete(
      auth,
      "inventory_levels.json?inventory_item_id=#{inventory_item_id}&location_id=#{location_id}"
    )
  end
end
