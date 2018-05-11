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
  Return a count of all the resources metafields.

  ## Example

    iex> ShopifyApi.Rest.Metafields.count(token, atom, integer)
    {:ok, %{ "count" => integer }}
  """
  def count(%AuthToken{} = auth, type, id) do
    Request.get(auth, resource_type(type, id))
  end

  @doc """
  Return a single metafield from a resource by it's ID.

  ## Example

    iex> ShopifyApi.Rest.Metafields.get(token, atom, integer)
    {:ok, %{ "metafield" => %{} }}
  """
  def get(%AuthToken{} = auth, type, id) do
    Request.get(auth, resource_type(type, id))
  end

  @doc """
  Creates a new metafield for a resource.

  ## Example

    iex> ShopifyApi.Rest.Metafields.create(token, atom, integer, map)
    {:ok, %{ "metafield" => %{} }}
  """
  def create(%AuthToken{} = auth, type, id, %{metafield: %{}} = metafield) do
    Request.post(auth, resource_type(type, id), metafield)
  end

  @doc """
  Update a metafield.

  ## Example

    iex> ShopifyApi.Rest.Metafields.update(token, atom, integer, map)
    {:ok, %{ "metafield" => %{} }}
  """
  def update(%AuthToken{} = auth, type, id, %{metafield: %{}} = metafield) do
    Request.post(auth, resource_type(type, id), metafield)
  end

  @doc """
  Delete a metafield by its ID.

  ## Example

    iex> ShopifyApi.Rest.Metafields.update(token, atom, integer, integer)
    {:ok, %{ "metafield" => %{} }}
  """
  def delete(%AuthToken{} = auth, type, id, metafield_id) do
    Request.post(auth, resource_type(type, id), metafield_id)
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

      :order ->
        "orders/#{id}/metafields.json"

      :page ->
        "pages/#{id}/metafields.json"

      :product ->
        "products/#{id}/metafields.json"

      :product_variant ->
        "products/#{id}/variants/#{id}/metafields.json"

      :product_image ->
        "Not implemented."

      :shop ->
        "metafields.json"
    end
  end
end
