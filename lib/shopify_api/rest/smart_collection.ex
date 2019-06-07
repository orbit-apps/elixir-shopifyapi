defmodule ShopifyAPI.REST.SmartCollection do
  @moduledoc """
  Shopify REST API Smart Collection resources
  """

  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST

  @doc """
  Get a list of all SmartCollections.

  ## Example
      iex> ShopifyAPI.REST.SmartCollection.all(token)
      {:ok, %{ "smart_collections" => [] }}
  """
  def all(%AuthToken{} = auth), do: REST.get(auth, "admin/smart_collections.json")

  @doc """
  Get a count of all SmartCollections.

  ## Example
      iex> ShopifyAPI.REST.SmartCollection.count(token)
      {:ok, { "count": integer }}
  """
  def count(%AuthToken{} = auth), do: REST.get(auth, "smart_collections/count.json")

  @doc """
  Return a single SmartCollection.

  ## Example
      iex> ShopifyAPI.REST.SmartCollection.get(auth, string)
      {:ok, %{ "smart_collection" => %{} }}
  """
  def get(%AuthToken{} = auth, smart_collection_id),
    do: REST.get(auth, "smart_collections/#{smart_collection_id}.json")

  @doc """
  Create a SmartCollection.

  ## Example
      iex> ShopifyAPI.REST.SmartCollection.create(auth, map)
      {:ok, %{ "smart_collection" => %{} }}
  """
  def create(%AuthToken{} = auth, %{smart_collection: %{}} = smart_collection),
    do: REST.post(auth, "smart_collections.json", smart_collection)

  @doc """
  Update an existing SmartCollection.

  ## Example
      iex> ShopifyAPI.REST.SmartCollection.update(auth, map)
      {:ok, %{ "smart_collection" => %{} }}
  """
  def update(
        %AuthToken{} = auth,
        %{smart_collection: %{id: smart_collection_id}} = smart_collection
      ),
      do: REST.put(auth, "smart_collections/#{smart_collection_id}.json", smart_collection)

  @doc """
  Delete a SmartCollection.

  ## Example
      iex> ShopifyAPI.REST.SmartCollection.delete(auth, string)
      {:ok, %{ "response": 200 }}
  """
  def delete(%AuthToken{} = auth, smart_collection_id),
    do: REST.delete(auth, "smart_collections/#{smart_collection_id}.json")
end
