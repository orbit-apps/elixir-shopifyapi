defmodule ShopifyAPI.REST.Metafield do
  @enforce_keys [:key, :namespace, :value, :value_type]
  defstruct key: "",
            namespace: "",
            value: 0,
            value_type: ""

  @moduledoc """
  ShopifyAPI REST API Metafield resource
  """

  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST.Request

  @doc """
  Get a list of all metafields that belong to a resource.

  ## Example

    iex> ShopifyAPI.REST.Metafields.all(token, atom, integer)
    {:ok, %{ "metafields" => [] }}
  """
  def all(%AuthToken{} = auth, type, id) do
    Request.get(auth, path_from_resource(type, id))
  end

  @doc """
  Return a count of metafields that belong to a Shop resource.

  ## Example

    iex> ShopifyAPI.REST.Metafields.count(token)
    {:ok, %{ "count" => integer }}
  """
  def count(%AuthToken{} = auth) do
    Request.get(auth, "metafields/count.json")
  end

  @doc """
  Return a count that belong to a resource and its metafields.

  ## Example

    iex> ShopifyAPI.REST.Metafields.count(token, atom, integer)
    {:ok, %{ "count" => integer }}
  """
  def count(%AuthToken{} = auth, type, resource_id) do
    Request.get(auth, path_from_resource(type, resource_id))
  end

  @doc """
  Return a list of metafields for a resource by it's ID.

  ## Example

    iex> ShopifyAPI.REST.Metafields.get(token, atom, integer)
    {:ok, %{ "metafields" => [] }}
  """
  def get(%AuthToken{} = auth, type, resource_id) do
    Request.get(auth, path_from_resource(type, resource_id))
  end

  @doc """
  Creates a new metafield for a resource.

  ## Example

    iex> ShopifyAPI.REST.Metafields.create(token, atom, integer, map)
    {:ok, %{ "metafield" => %{} }}
  """
  def create(%AuthToken{} = auth, type, resource_id, %__MODULE__{} = metafield) do
    Request.post(auth, path_from_resource(type, resource_id), metafield)
  end

  @doc """
  Update a metafield.

  ## Example

    iex> ShopifyAPI.REST.Metafields.update(token, atom, integer, map)
    {:ok, %{ "metafield" => %{} }}
  """
  def update(%AuthToken{} = auth, type, resource_id, %__MODULE__{} = metafield) do
    Request.put(auth, path_from_resource(type, resource_id), metafield)
  end

  @doc """
  Delete a metafield by its Metafield ID.

  ## Example

    iex> ShopifyAPI.REST.Metafields.update(token, integer)
    {:ok, %{ "metafield" => %{} }}
  """
  def delete(%AuthToken{} = auth, metafield_id) do
    Request.delete(auth, path_from_resource(:metafield, metafield_id))
  end

  ## Private

  defp path_from_resource(resource, id) do
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

      _ ->
        "Resource not found"
    end
  end
end
