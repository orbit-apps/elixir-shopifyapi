defmodule ShopifyAPI.REST.InventoryItem do
  @moduledoc """
  ShopifyAPI REST API InventoryItem resource
  """

  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST

  require Logger

  @doc """
  Return a list of inventory items.

  NOTE: Not implemented.

  ## Example

      iex> ShopifyAPI.REST.InventoryItem.all(auth)
      {:error, "Not implemented" }
  """
  def all do
    Logger.warn("#{__MODULE__} error, resource not implemented.")
    {:error, "Not implemented"}
  end

  @doc """
  Get a single inventory item by its ID.

  ## Example

      iex> ShopifyAPI.REST.InventoryItem.get(auth, integer)
      {:ok, %{} = inventory_item}
  """
  def get(%AuthToken{} = auth, inventory_item_id, params \\ [], options \\ []),
    do:
      REST.get(
        auth,
        "inventory_items/#{inventory_item_id}.json",
        params,
        Keyword.merge([pagination: :none], options)
      )

  @doc """
  Update an existing inventory item.

  ## Example

      iex> ShopifyAPI.REST.InventoryItem.update(auth, map)
      {:ok, %{} = inventory_item}
  """
  def update(%AuthToken{} = auth, %{inventory_item: %{id: inventory_item_id}} = inventory_item),
    do: REST.put(auth, "inventory_items/#{inventory_item_id}.json", inventory_item)
end
