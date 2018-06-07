defmodule ShopifyAPI.REST.Product do
  @moduledoc """
  Shopify REST API Product resources
  """

  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST.Request

  @doc """
  Get a list of all the products.

  ## Example

    iex> ShopifyAPI.REST.Product.all(auth)
    {:ok, %{ "products" => [] }}
  """
  def all(%AuthToken{} = auth), do: Request.get(auth, "products.json")

  @doc """
  Return a single product.

  ## Example

    iex> ShopifyAPI.REST.Product.get(auth, integer)
    {:ok, %{ "product" => %{} }}
  """
  def get(%AuthToken{} = auth, product_id), do: Request.get(auth, "products/#{product_id}.json")

  @doc """
  Return a count of products.

  ## Example

    iex> ShopifyAPI.REST.Product.count(auth)
    {:ok, %{ "count" => integer }}
  """
  def count(%AuthToken{} = auth), do: Request.get(auth, "products/count.json")

  @doc """
  Update a product.

  ## Example

    iex> ShopifyAPI.REST.Product.update(auth, map)
    {:ok, %{ "product" => %{} }}
  """
  def update(%AuthToken{} = auth, %{"product" => %{"id" => product_id} = product}),
    do: update(auth, %{product: product |> Map.put(:id, product_id)})

  def update(%AuthToken{} = auth, %{product: %{id: product_id}} = product),
    do: Request.put(auth, "products/#{product_id}.json", product)

  @doc """
  Delete a product.

  ## Example

      iex> ShopifyAPI.REST.Product.delete(auth, integer)
      {:ok, 200 }
  """
  def delete(%AuthToken{} = auth, product_id),
    do: Request.delete(auth, "products/#{product_id}.json")

  @doc """
  Create a new product.

  ## Example

      iex> ShopifyAPI.REST.Product.create(auth, map)
      {:ok, %{ "product" => %{} }}
  """
  def create(%AuthToken{} = auth, %{"product" => %{} = product}),
    do: create(auth, %{product: product})

  def create(%AuthToken{} = auth, %{product: %{}} = product),
    do: Request.post(auth, "products.json", product)
end
