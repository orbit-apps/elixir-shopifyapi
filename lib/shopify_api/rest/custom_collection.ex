defmodule ShopifyAPI.REST.CustomCollection do
  @moduledoc """
  Shopify REST API Custom Collection resources
  """

  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST

  @doc """
  Get a list of all the custom collections.

  ## Example
      iex> ShopifyAPI.REST.CustomCollection.all(token)
      {:ok, [%{}, ...] = custom_collections}
  """
  def all(%AuthToken{} = auth, params \\ [], options \\ []),
    do: REST.get(auth, "admin/custom_collections.json", params, options)

  @doc """
  Get a count of all custom collections.

  ## Example
      iex> ShopifyAPI.REST.CustomCollection.count(token)
      {:ok, integer}
  """
  def count(%AuthToken{} = auth, params \\ [], options \\ []),
    do:
      REST.get(
        auth,
        "custom_collections/count.json",
        params,
        Keyword.merge([pagination: :none], options)
      )

  @doc """
  Return a single custom collection.

  ## Example
      iex> ShopifyAPI.REST.CustomCollection.get(auth, string)
      {:ok, %{} = custom_collections}
  """
  def get(%AuthToken{} = auth, custom_collection_id, params \\ [], options \\ []),
    do:
      REST.get(
        auth,
        "custom_collections/#{custom_collection_id}.json",
        params,
        Keyword.merge([pagination: :none], options)
      )

  @doc """
  Create a custom collection.

  ## Example
      iex> ShopifyAPI.REST.CustomCollection.create(auth, map)
      {:ok, %{} = custom_collection}
  """
  def create(%AuthToken{} = auth, %{custom_collection: %{}} = custom_collection),
    do: REST.post(auth, "custom_collections.json", custom_collection)

  @doc """
  Update an existing custom collection.

  ## Example
      iex> ShopifyAPI.REST.CustomCollection.update(auth, string, map)
      {:ok, %{} = custom_collection}
  """
  def update(
        %AuthToken{} = auth,
        %{custom_collection: %{id: custom_collection_id}} = custom_collection
      ),
      do: REST.put(auth, "custom_collections/#{custom_collection_id}.json", custom_collection)

  @doc """
  Delete a custom collection.

  ## Example
      iex> ShopifyAPI.REST.CustomCollection.delete(auth, string)
      {:ok, %{ "response": 200 }}
  """
  def delete(%AuthToken{} = auth, custom_collection_id),
    do: REST.delete(auth, "custom_collections/#{custom_collection_id}.json")
end
