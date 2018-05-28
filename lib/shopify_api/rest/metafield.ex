defmodule ShopifyApi.Rest.Metafield do
  @moduledoc """
  ShopifyApi REST API Metafield resource
  """

  alias ShopifyApi.AuthToken
  alias ShopifyApi.Rest.Request

  @doc """
  Get a list of all metafields that belong to a resource.

  ## Example

    iex> ShopifyApi.Rest.Metafields.all(token, atom, integer)
    {:ok, %{ "metafields" => [] }}
  """
  def all(%AuthToken{} = auth, type, id) do
    Request.get(auth, resource_type(type, id))
  end

  @doc """
  Return a count of metafields that belong to a Shop resource.

  ## Example

    iex> ShopifyApi.Rest.Metafields.count(token)
    {:ok, %{ "count" => integer }}
  """
  def count(%AuthToken{} = auth) do
    Request.get(auth, "metafields/count.json")
  end

  @doc """
  Return a count that belong to a resource and its metafields.

  ## Example

    iex> ShopifyApi.Rest.Metafields.count(token, atom, integer)
    {:ok, %{ "count" => integer }}
  """
  def count(%AuthToken{} = auth, type, resource_id) do
    Request.get(auth, resource_type(type, resource_id))
  end

  @doc """
  Return a list of metafields for a resource by it's ID.

  ## Example

    iex> ShopifyApi.Rest.Metafields.get(token, atom, integer)
    {:ok, %{ "metafields" => [] }}
  """
  def get(%AuthToken{} = auth, type, resource_id) do
    Request.get(auth, resource_type(type, resource_id))
  end

  @doc """
  Creates a new metafield for a resource.

  ## Example

    iex> ShopifyApi.Rest.Metafields.create(token, atom, integer, map)
    {:ok, %{ "metafield" => %{} }}
  """
  def create(%AuthToken{} = auth, type, resource_id, %{metafield: %{}} = metafield) do
    Request.post(auth, resource_type(type, resource_id), metafield)
  end

  @doc """
  Update a metafield.

  ## Example

    iex> ShopifyApi.Rest.Metafields.update(token, atom, integer, map)
    {:ok, %{ "metafield" => %{} }}
  """
  def update(%AuthToken{} = auth, type, resource_id, %{metafield: %{}} = metafield) do
    Request.put(auth, resource_type(type, resource_id), metafield)
  end

  @doc """
  Delete a metafield by its Metafield ID.

  ## Example

    iex> ShopifyApi.Rest.Metafields.update(token, integer)
    {:ok, %{ "metafield" => %{} }}
  """
  def delete(%AuthToken{} = auth, metafield_id) do
    Request.delete(auth, resource_type(:metafield, metafield_id))
  end

  ## Private

  defp resource_type(resource, id) do
    case resource do
      :article ->
        "blogs/#{id}/articles/#{id}/metafields.json"

      :blog ->
        "blogs/#{id}/metafields.json"

      :collection ->
        "collections/#{id}/metafields.json"

      :draft_order ->
        "draft_orders/#{id}/metafields.json"

      :metafield ->
        "metafields/#{id}.json"

      :order ->
        "orders/#{id}/metafields.json"

      :page ->
        "pages/#{id}/metafields.json"

      :product ->
        "products/#{id}/metafields.json"

      :product_variant ->
        "Not implemented."

      :product_image ->
        "Not implemented."

      :shop ->
        "metafields.json"
    end
  end
end
