defmodule ShopifyApi.Product do
  @moduledoc """
  """
  alias ShopifyApi.AuthToken
  alias ShopifyApi.Request

  @doc """
  ## Example

  iex> ShopifyApi.Product.all(auth)
  {:ok, %{"products" => [%{"product_id" => "_", "title" => "Testing Create Product"}]}}
  """
  def all(%AuthToken{} = auth) do
    Request.get(auth, "products.json")
  end

  def get(%AuthToken{} = auth, product_id) do
    Request.get(auth, "products/#{product_id}.json")
  end

  def update(%AuthToken{} = auth, %{product: %{product_id: product_id}} = product) do
    Request.put(auth, "products/#{product_id}.json", product)
  end

  @doc """
  ## Example

  iex> ShopifyApi.Product.delete(auth, 598612213811)
  {:ok, %{}}
  """
  def delete(%AuthToken{} = auth, product_id) do
    Request.delete(auth, "products/#{product_id}.json")
  end

  @doc """
  ## Example

  iex> ShopifyApi.Product.create(auth, %{product: %{body_html: "Testing create", title: "Testing Create Product"}})
  {:ok, %{"product" => %{"product_id" => "_", "title" => "Testing Create Product"}}}
  """
  def create(%AuthToken{} = auth, %{product: %{}} = product) do
    Request.post(auth, "products.json", product)
  end
end
