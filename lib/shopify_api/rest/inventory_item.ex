defmodule ShopifyApi.Rest.InventoryItem do
  @moduledoc """
  ShopifyApi REST API InventoryItem resource
  """
  require Logger
  alias ShopifyApi.AuthToken
  alias ShopifyApi.Rest.Request

  @doc """
  Return a list of inventory items.

  NOTE: Not implemented.

  ## Example

      iex> ShopifyApi.Rest.InventoryItem.all(auth)
      {:error, "Not implemented" }
  """
  def all() do
    Logger.warn("#{__MODULE__} error, resource not implemented.")
    {:error, "Not implemented"}
  end

  @doc """
  Get a single inventory item by its ID.

  ## Example

      iex> ShopifyApi.Rest.InventoryItem.get(auth, integer)
      {:ok, { "inventory_item" => %{} }}
  """
  def get(%AuthToken{} = auth, inventory_item_id) do
    Request.get(auth, "inventory_items/#{inventory_item_id}.json")
  end

  @doc """
  Update an existing inventory item.

  ## Example

      iex> ShopifyApi.Rest.InventoryItem.update(auth, map)
      {:ok, { "inventory_item" => %{} }}
  """
  def update(%AuthToken{} = auth, %{inventory_item: %{id: inventory_item_id}} = inventory_item) do
    Request.put(auth, "inventory_items/#{inventory_item_id}.json", inventory_item)
  end
end
