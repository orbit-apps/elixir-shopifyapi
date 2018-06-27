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
    Request.get(auth, resource_path(type, id))
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
    Request.get(auth, resource_path(type, resource_id))
  end

  @doc """
  Return a list of metafields for a resource by it's ID.

  ## Example

    iex> ShopifyAPI.REST.Metafields.get(token, atom, integer)
    {:ok, %{ "metafields" => [] }}
  """
  def get(%AuthToken{} = auth, type, resource_id) do
    Request.get(auth, resource_path(type, resource_id))
  end

  @doc """
  Creates a new metafield for a resource.

  ## Example

    iex> ShopifyAPI.REST.Metafields.create(token, atom, integer, map)
    {:ok, %{ "metafield" => %{} }}
  """
  def create(%AuthToken{} = auth, type, resource_id, %__MODULE__{} = metafield) do
    Request.post(auth, resource_path(type, resource_id), metafield)
  end

  @doc """
  Update a metafield.

  ## Example

    iex> ShopifyAPI.REST.Metafields.update(token, atom, integer, map)
    {:ok, %{ "metafield" => %{} }}
  """
  def update(%AuthToken{} = auth, type, resource_id, %__MODULE__{} = metafield) do
    Request.put(auth, resource_path(type, resource_id), metafield)
  end

  @doc """
  Delete a metafield by its Metafield ID.

  ## Example

    iex> ShopifyAPI.REST.Metafields.update(token, integer)
    {:ok, %{ "metafield" => %{} }}
  """
  def delete(%AuthToken{} = auth, metafield_id) do
    Request.delete(auth, resource_path(:metafield, metafield_id))
  end

  ## Private
  defp resource_path(:article, id), do: "blogs/#{id}/articles/#{id}/metafields.json"
  defp resource_path(:blog, id), do: "blogs/#{id}/metafields.json"

  defp resource_path(:collection, id), do: "collections/#{id}/metafields.json"

  defp resource_path(:draft_order, id), do: "draft_orders/#{id}/metafields.json"

  defp resource_path(:metafield, id), do: "metafields/#{id}.json"

  defp resource_path(:order, id), do: "orders/#{id}/metafields.json"

  defp resource_path(:page, id), do: "pages/#{id}/metafields.json"

  defp resource_path(:product, id), do: "products/#{id}/metafields.json"

  defp resource_path(:product_variant), do: "Not implemented."

  # TODO: Update this when PR for ProductImage closes.
  defp resource_path(:product_image), do: "Not implemented."

  defp resource_path(:shop), do: "metafields.json"
end
