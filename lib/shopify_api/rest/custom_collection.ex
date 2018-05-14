defmodule ShopifyApi.Rest.CustomCollection do
  @moduledoc """
  Shopify REST API Custom Collection resources
  """

  alias ShopifyApi.AuthToken
  alias ShopifyApi.Rest.Request

  @doc """
  Get a list of all the custom collections.

  ## Example
      iex> ShopifyApi.Rest.CustomCollection.all(token)
      {:ok, %{ "custom_collections" => %{} }}
  """
  def all(%AuthToken{} = auth) do
    Request.get(auth, "admin/custom_collections.json")
  end

  @doc """
  Get a count of all custom collections.

  ## Example
      iex> ShopifyApi.Rest.CustomCollection.count(token)
      {:ok, { "count": integer }}
  """
  def count(%AuthToken{} = auth) do
    Request.get(auth, "custom_collections/count.json")
  end

  @doc """
  Return a single custom collection.

  ## Example
      iex> ShopifyApi.Rest.CustomCollection.get(token, string)
      {:ok, %{ "custom_collections" => %{} }}
  """
  def get(%AuthToken{} = auth, custom_collection_id) do
    Request.get(auth, "custom_collections/#{custom_collection_id}.json")
  end

  @doc """
  Create a custom collection.

  ## Example
      iex> ShopifyApi.Rest.CustomCollection.create(token, map)
      {:ok, %{ "custom_collection" => %{} }}
  """
  def create(%AuthToken{} = auth, %{custom_collection: %{}} = custom_collection) do
    Request.post(auth, "custom_collections.json", custom_collection)
  end

  @doc """
  Update an existing custom collection.

  ## Example
      iex> ShopifyApi.Rest.CustomCollection.update(token, string, map)
      {:ok, %{ "custom_collection" => %{} }}
  """
  def update(
        %AuthToken{} = auth,
        %{custom_collection: %{id: custom_collection_id}} = custom_collection
      ) do
    Request.put(auth, "custom_collections/#{custom_collection_id}.json", custom_collection)
  end

  @doc """
  Delete a custom collection.

  ## Example
      iex> ShopifyApi.Rest.CustomCollection.delete(token, string)
      {:ok, %{ "response": 200 }}
  """
  def delete(%AuthToken{} = auth, custom_collection_id) do
    Request.delete(auth, "custom_collections/#{custom_collection_id}.json")
  end
end
