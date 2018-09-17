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
  def all(%AuthToken{} = auth, type, id), do: Request.get(auth, resource_path(type, id))

  @doc """
  Return a count of metafields that belong to a Shop resource.

  ## Example

    iex> ShopifyAPI.REST.Metafields.count(token)
    {:ok, %{ "count" => integer }}
  """
  def count(%AuthToken{} = auth), do: Request.get(auth, "metafields/count.json")

  @doc """
  Return a count that belong to a resource and its metafields.

  ## Example

    iex> ShopifyAPI.REST.Metafields.count(token, atom, integer)
    {:ok, %{ "count" => integer }}
  """
  def count(%AuthToken{} = auth, type, resource_id),
    do: Request.get(auth, resource_path(type, resource_id))

  @doc """
  Return a list of metafields for a resource by it's ID.

  ## Example

    iex> ShopifyAPI.REST.Metafields.get(token, atom, integer)
    {:ok, %{ "metafields" => [] }}
  """
  def get(%AuthToken{} = auth, type, resource_id),
    do: Request.get(auth, resource_path(type, resource_id))

  @doc """
  Creates a new metafield.

  ## Example

    iex> ShopifyAPI.REST.Metafields.create(token, map)
    {:ok, %{ "metafield" => %{} }}
  """
  def create(%AuthToken{} = auth, metafield), do: Request.post(auth, "metafields.json", metafield)

  @doc """
  Creates a new metafield for a resource.

  ## Example

    iex> ShopifyAPI.REST.Metafields.create(token, atom, integer, map)
    {:ok, %{ "metafield" => %{} }}
  """
  def create(%AuthToken{} = auth, type, resource_id, metafield),
    do: Request.post(auth, resource_path(type, resource_id), metafield)

  @doc """
  Update a metafield.

  ## Example

    iex> ShopifyAPI.REST.Metafields.update(token, atom, integer, map)
    {:ok, %{ "metafield" => %{} }}
  """
  def update(%AuthToken{} = auth, type, resource_id, %{metafield: %{id: id}} = metafield),
    do: Request.put(auth, resource_path(type, resource_id, id), metafield)

  @doc """
  Delete a metafield by its Metafield ID.

  ## Example

    iex> ShopifyAPI.REST.Metafields.update(token, integer)
    {:ok, %{ "metafield" => %{} }}
  """
  def delete(%AuthToken{} = auth, metafield_id),
    do: Request.delete(auth, resource_path(:metafield, metafield_id))

  ## Private

  defp resource_path(resource, id) when is_binary(resource),
    do: resource_path(String.to_existing_atom(resource), id)

  defp resource_path(:blog, blog_id), do: "blogs/#{blog_id}/metafields.json"

  defp resource_path(:collection, collection_id),
    do: "collections/#{collection_id}/metafields.json"

  defp resource_path(:customer, customer_id), do: "customers/#{customer_id}/metafields.json"
  defp resource_path(:draft_order, draft_id), do: "draft_orders/#{draft_id}/metafields.json"
  defp resource_path(:metafield, metafield_id), do: "metafields/#{metafield_id}.json"
  defp resource_path(:order, order_id), do: "orders/#{order_id}/metafields.json"
  defp resource_path(:page, page_id), do: "pages/#{page_id}/metafields.json"
  defp resource_path(:product, product_id), do: "products/#{product_id}/metafields.json"
  defp resource_path(:variant, variant_id), do: "variants/#{variant_id}/metafields.json"

  defp resource_path(resource, id, meta_id) when is_binary(resource),
    do: resource_path(String.to_existing_atom(resource), id, meta_id)

  defp resource_path(:blog, blog_id, id), do: "blogs/#{blog_id}/metafields/#{id}.json"

  defp resource_path(:collection, collection_id, id),
    do: "collections/#{collection_id}/metafields/#{id}.json"

  defp resource_path(:draft_order, draft_id, id),
    do: "draft_orders/#{draft_id}/metafields/#{id}.json"

  defp resource_path(:order, order_id, id), do: "orders/#{order_id}/metafields/#{id}.json"
  defp resource_path(:page, page_id, id), do: "pages/#{page_id}/metafields/#{id}.json"
  defp resource_path(:product, product_id, id), do: "products/#{product_id}/metafields/#{id}.json"
  defp resource_path(:variant, variant_id, id), do: "variants/#{variant_id}/metafields/#{id}.json"

  defp resource_path(:article), do: "Not implemented."
  # TODO: Update this when PR for ProductImage closes.
  defp resource_path(:product_image), do: "Not implemented."
  defp resource_path(:shop), do: "metafields.json"
end
