defmodule ShopifyAPI.REST.ProductImage do
  @moduledoc """
  ShopifyApi REST API Product Image resource
  """

  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST

  @doc """
  Return a list of all products images.

  ## Example

      iex> ShopifyApi.Rest.ProductImage.all(auth, integer)
      {:ok, [] = images}
  """
  def all(%AuthToken{} = auth, product_id, params \\ [], options \\ []),
    do:
      REST.get(
        auth,
        "products/#{product_id}/images.json",
        params,
        Keyword.merge([pagination: :none], options)
      )

  @doc """
  Get a count of all product images.

  ## Example

      iex> ShopifyApi.Rest.ProductImage.count(auth)
      {:ok, integer = count}
  """
  def count(%AuthToken{} = auth, product_id, params \\ [], options \\ []),
    do:
      REST.get(
        auth,
        "products/#{product_id}/images/count.json",
        params,
        Keyword.merge([pagination: :none], options)
      )

  @doc """
  Get all images for a single product.

  ## Example

      iex> ShopifyApi.Rest.ProductImage.get(auth, map)
      {:ok, %{} = image}
  """
  @deprecated "Duplicate of all/2"
  def get(%AuthToken{} = auth, product_id),
    do: REST.get(auth, "products/#{product_id}/images.json")

  @doc """
  Get a single product image.

  ## Example

      iex> ShopifyApi.Rest.ProductImage.get(auth, map)
      {:ok, %{} = image}
  """
  def get(%AuthToken{} = auth, product_id, image_id, params \\ [], options \\ []),
    do:
      REST.get(
        auth,
        "products/#{product_id}/images/#{image_id}.json",
        params,
        Keyword.merge([pagination: :none], options)
      )

  @doc """
  Create a new product image.

  ## Example

      iex> ShopifyApi.Rest.ProductImage.create(auth, integer, map)
      {:ok, %{} = image}
  """
  def create(%AuthToken{} = auth, product_id, %{image: %{}} = image),
    do: REST.post(auth, "products/#{product_id}/images.json", image)

  @doc """
  Update an existing product image.

  ## Example

      iex> ShopifyApi.Rest.ProductImage.update(auth, integer, map)
      {:ok, %{} = image}
  """
  def update(%AuthToken{} = auth, product_id, %{image: %{id: image_id}} = image),
    do: REST.put(auth, "products/#{product_id}/images/#{image_id}.json", image)

  @doc """
  Delete a product image.

  ## Example

      iex> ShopifyApi.Rest.ProductImage.delete(auth, integer, integer)
      {:ok, 200 }}
  """
  def delete(%AuthToken{} = auth, product_id, image_id),
    do: REST.delete(auth, "products/#{product_id}/images/#{image_id}.json")
end
