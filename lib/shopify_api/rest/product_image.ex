defmodule ShopifyAPI.REST.ProductImage do
  @moduledoc """
  ShopifyApi REST API Product Image resource
  """

  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST.Request

  @doc """
  Return a list of all products images.

  ## Example

      iex> ShopifyApi.Rest.ProductImage.all(auth, integer)
      {:ok, { "images" => [] }}
  """
  def all(%AuthToken{} = auth, product_id) do
    Request.get(auth, "products/#{product_id}/images.json")
  end

  @doc """
  Get a count of all product images.

  ## Example

      iex> ShopifyApi.Rest.ProductImage.count(auth)
      {:ok, { "count" => integer }}
  """
  def count(%AuthToken{} = auth, product_id) do
    Request.get(auth, "products/#{product_id}/images/count.json")
  end

  @doc """
  Get all images for a single product.

  ## Example

      iex> ShopifyApi.Rest.ProductImage.get(auth, map)
      {:ok, { "image" => %{} }}
  """
  def get(%AuthToken{} = auth, product_id) do
    Request.get(auth, "products/#{product_id}/images.json")
  end

  @doc """
  Get a single product image.

  ## Example

      iex> ShopifyApi.Rest.ProductImage.get(auth, map)
      {:ok, { "image" => %{} }}
  """
  def get(%AuthToken{} = auth, product_id, image_id) do
    Request.get(auth, "products/#{product_id}/images/#{image_id}.json")
  end

  @doc """
  Create a new product image.

  ## Example

      iex> ShopifyApi.Rest.ProductImage.create(auth, integer, map)
      {:ok, { "image" => %{} }}
  """
  def create(%AuthToken{} = auth, product_id, %{image: %{}} = image) do
    Request.post(auth, "products/#{product_id}/images.json", image)
  end

  @doc """
  Update an existing product image.

  ## Example

      iex> ShopifyApi.Rest.ProductImage.update(auth, integer, map)
      {:ok, { "image" => %{} }}
  """
  def update(%AuthToken{} = auth, product_id, %{image: %{id: image_id}} = image) do
    Request.put(auth, "products/#{product_id}/images/#{image_id}.json", image)
  end

  @doc """
  Delete a product image.

  ## Example

      iex> ShopifyApi.Rest.ProductImage.delete(auth, integer, integer)
      {:ok, 200 }}
  """
  def delete(%AuthToken{} = auth, product_id, image_id) do
    Request.delete(auth, "products/#{product_id}/images/#{image_id}.json")
  end
end
