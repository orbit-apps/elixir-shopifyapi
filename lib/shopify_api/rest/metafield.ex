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
  alias ShopifyAPI.REST

  @doc """
  Get a list of all metafields that belong to a resource.

  ## Example

    iex> ShopifyAPI.REST.Metafields.all(auth)
    {:ok, [] = metafields }}

    iex> ShopifyAPI.REST.Metafields.all(token, atom, integer)
    {:ok, [] = metafields }}
  """
  # TODO(BJ) - add options without defaults conflicting
  def all(%AuthToken{} = auth, params \\ []),
    do: REST.get(auth, "metafields.json", params)

  def all(%AuthToken{} = auth, type, resource_id, params \\ []),
    do: REST.get(auth, resource_path(type, resource_id), params)

  @doc """
  Return a count of metafields that belong to a Shop resource.

  ## Example

    iex> ShopifyAPI.REST.Metafields.count(token)
    {:ok, integer = count}
  """
  # TODO(BJ) - add options without defaults conflicting
  def count(%AuthToken{} = auth, params \\ []),
    do: REST.get(auth, "metafields/count.json", params, pagination: :none)

  @doc """
  Return a count that belong to a resource and its metafields.

  ## Example

    iex> ShopifyAPI.REST.Metafields.count(auth, atom, integer)
    {:ok, integer = count}
  """
  def count(%AuthToken{} = auth, type, resource_id, params \\ []),
    do: REST.get(auth, resource_path(type, resource_id), params, pagination: :none)

  @doc """
  Return a list of metafields for a resource by it's ID.

  ## Example

    iex> ShopifyAPI.REST.Metafields.get(auth, atom, integer)
    {:ok, [] = metafields}
  """
  def get(%AuthToken{} = auth, type, resource_id, params \\ [], options \\ []),
    do:
      REST.get(
        auth,
        resource_path(type, resource_id),
        params,
        Keyword.merge([pagination: :none], options)
      )

  @doc """
  Creates a new metafield.

  ## Example

    iex> ShopifyAPI.REST.Metafields.create(auth, map)
    {:ok, %{} = metafield}
  """
  def create(%AuthToken{} = auth, metafield), do: REST.post(auth, "metafields.json", metafield)

  @doc """
  Creates a new metafield for a resource.

  ## Example

    iex> ShopifyAPI.REST.Metafields.create(auth, atom, integer, map)
    {:ok, %{} = metafield}
  """
  def create(%AuthToken{} = auth, type, resource_id, metafield),
    do: REST.post(auth, resource_path(type, resource_id), metafield)

  @doc """
  Update a metafield.

  ## Example

    iex> ShopifyAPI.REST.Metafields.update(auth, atom, integer, map)
    {:ok, %{} = metafield}
  """
  def update(%AuthToken{} = auth, type, resource_id, %{metafield: %{id: id}} = metafield),
    do: REST.put(auth, resource_path(type, resource_id, id), metafield)

  @doc """
  Delete a metafield by its Metafield ID.

  ## Example

    iex> ShopifyAPI.REST.Metafields.update(auth, integer)
    {:ok, %{} = metafield}
  """
  def delete(%AuthToken{} = auth, metafield_id),
    do: REST.delete(auth, resource_path(:metafield, metafield_id))

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
end
