defmodule ShopifyApi.Rest.SmartCollection do
  @moduledoc """
  Shopify REST API Smart Collection resources
  """

  alias ShopifyApi.AuthToken
  alias ShopifyApi.Rest.Request

  @doc """
  Get a list of all SmartCollections.

  ## Example
      iex> ShopifyApi.Rest.SmartCollection.all(token)
      {:ok, %{ "smart_collections" => [] }}
  """
  def all(%AuthToken{} = auth) do
    Request.get(auth, "admin/smart_collections.json")
  end

  @doc """
  Get a count of all SmartCollections.

  ## Example
      iex> ShopifyApi.Rest.SmartCollection.count(token)
      {:ok, { "count": integer }}
  """
  def count(%AuthToken{} = auth) do
    Request.get(auth, "smart_collections/count.json")
  end

  @doc """
  Return a single SmartCollection.

  ## Example
      iex> ShopifyApi.Rest.SmartCollection.get(token, string)
      {:ok, %{ "smart_collection" => %{} }}
  """
  def get(%AuthToken{} = auth, smart_collection_id) do
    Request.get(auth, "smart_collections/#{smart_collection_id}.json")
  end

  @doc """
  Create a SmartCollection.

  ## Example
      iex> ShopifyApi.Rest.SmartCollection.create(token, map)
      {:ok, %{ "smart_collection" => %{} }}
  """
  def create(%AuthToken{} = auth, %{smart_collection: %{}} = smart_collection) do
    Request.post(auth, "smart_collections.json", smart_collection)
  end

  @doc """
  Update an existing SmartCollection.

  ## Example
      iex> ShopifyApi.Rest.SmartCollection.update(token, map)
      {:ok, %{ "smart_collection" => %{} }}
  """
  def update(
        %AuthToken{} = auth,
        %{smart_collection: %{id: smart_collection_id}} = smart_collection
      ) do
    Request.put(auth, "smart_collections/#{smart_collection_id}.json", smart_collection)
  end

  @doc """
  Delete a SmartCollection.

  ## Example
      iex> ShopifyApi.Rest.SmartCollection.delete(token, string)
      {:ok, %{ "response": 200 }}
  """
  def delete(%AuthToken{} = auth, smart_collection_id) do
    Request.delete(auth, "smart_collections/#{smart_collection_id}.json")
  end
end
