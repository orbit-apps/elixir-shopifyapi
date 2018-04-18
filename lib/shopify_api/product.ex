defmodule ShopifyApi.Product do
  @moduledoc """
  """
  alias ShopifyApi.Shop
  alias ShopifyApi.Request

  @doc """
  ## Example

  iex> ShopifyApi.Product.all(shop)
  {:ok, %{"products" => [%{"product_id" => "_", "title" => "Testing Create Product"}]}}
  """
  def all(%Shop{} = shop) do
    Request.get(shop, "products.json")
  end

  def get(%Shop{} = shop, product_id) do
    Request.get(shop, "products/#{product_id}.json")
  end

  def update(%Shop{} = shop, %{product: %{product_id: product_id}} = product) do
    Request.put(shop, "products/#{product_id}.json", product)
  end

  @doc """
  ## Example

  iex> ShopifyApi.Product.delete(shop, 598612213811)
  {:ok, %{}}
  """
  def delete(%Shop{} = shop, product_id) do
    Request.delete(shop, "products/#{product_id}.json")
  end

  @doc """
  ## Example

  iex> ShopifyApi.Product.create(shop, %{product: %{body_html: "Testing create", title: "Testing Create Product"}})
  {:ok, %{"product" => %{"product_id" => "_", "title" => "Testing Create Product"}}}
  """
  def create(%Shop{} = shop, %{product: %{}} = product) do
    Request.post(shop, "products.json", product)
  end
end
