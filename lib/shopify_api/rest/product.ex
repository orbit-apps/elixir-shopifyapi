defmodule ShopifyApi.Rest.Product do
  @moduledoc """
  Shopify REST API Product resources
  """

  alias ShopifyApi.AuthToken
  alias ShopifyApi.Rest.Request

  @doc """
  Get a list of all the products.

  ## Example

    iex> ShopifyApi.Rest.Product.all(auth)
    {:ok, %{ "products" => [] }}
  """
  def all(%AuthToken{} = auth) do
    Request.get(auth, "products.json")
  end

  @doc """
  Return a single product.

  ## Example

    iex> ShopifyApi.Rest.Product.get(auth, integer)
    {:ok, %{ "product" => %{} }}
  """
  def get(%AuthToken{} = auth, product_id) do
    Request.get(auth, "products/#{product_id}.json")
  end

  @doc """
  Return a count of products.

  ## Example

    iex> ShopifyApi.Rest.Product.count(auth)
    {:ok, %{ "count" => integer }}
  """
  def count(%AuthToken{} = auth) do
    Request.get(auth, "products/count.json")
  end

  @doc """
  Update a product.

  ## Example

    iex> ShopifyApi.Rest.Product.update(auth, map)
    {:ok, %{ "product" => %{} }}
  """
  def update(%AuthToken{} = auth, %{product: %{id: product_id}} = product) do
    Request.put(auth, "products/#{product_id}.json", product)
  end

  @doc """
  Delete a product.

  ## Example

      iex> ShopifyApi.Rest.Product.delete(auth, integer)
      {:ok, 200 }
  """
  def delete(%AuthToken{} = auth, product_id) do
    Request.delete(auth, "products/#{product_id}.json")
  end

  @doc """
  Create a new product.

  ## Example

      iex> ShopifyApi.Rest.Product.create(auth, map)
      {:ok, %{ "product" => %{} }}
  """
  def create(%AuthToken{} = auth, %{product: %{}} = product) do
    Request.post(auth, "products.json", product)
  end
end
