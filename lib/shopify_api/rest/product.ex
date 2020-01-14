defmodule ShopifyAPI.REST.Product do
  @moduledoc """
  Shopify REST API Product resources
  """

  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST

  @doc """
  Get a list of all the products.

  ## Example

    iex> ShopifyAPI.REST.Product.all(auth)
    {:ok, %{ "products" => [] }}
  """
  def all(%AuthToken{} = auth, params \\ []), do: REST.get(auth, "products.json", params)

  @doc """
  Return a single product.

  ## Example

    iex> ShopifyAPI.REST.Product.get(auth, integer)
    {:ok, %{ "product" => %{} }}
  """
  def get(%AuthToken{} = auth, product_id, params \\ []),
    do: REST.get(auth, "products/#{product_id}.json", params)

  @doc """
  Return a count of products.

  ## Example

    iex> ShopifyAPI.REST.Product.count(auth)
    {:ok, %{ "count" => integer }}
  """
  def count(%AuthToken{} = auth, params \\ []), do: REST.get(auth, "products/count.json", params)

  @doc """
  Update a product.

  ## Example

    iex> ShopifyAPI.REST.Product.update(auth, map)
    {:ok, %{ "product" => %{} }}
  """
  def update(%AuthToken{} = auth, %{"product" => %{"id" => product_id} = product}),
    do: update(auth, %{product: Map.put(product, :id, product_id)})

  def update(%AuthToken{} = auth, %{product: %{id: product_id}} = product),
    do: REST.put(auth, "products/#{product_id}.json", product)

  @doc """
  Delete a product.

  ## Example

      iex> ShopifyAPI.REST.Product.delete(auth, integer)
      {:ok, 200 }
  """
  def delete(%AuthToken{} = auth, product_id),
    do: REST.delete(auth, "products/#{product_id}.json")

  @doc """
  Create a new product.

  ## Example

      iex> ShopifyAPI.REST.Product.create(auth, map)
      {:ok, %{ "product" => %{} }}
  """
  def create(%AuthToken{} = auth, %{"product" => %{} = product}),
    do: create(auth, %{product: product})

  def create(%AuthToken{} = auth, %{product: %{}} = product),
    do: REST.post(auth, "products.json", product)
end
