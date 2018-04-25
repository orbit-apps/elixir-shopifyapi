defmodule ShopifyApi.ProductVariant do
  @moduledoc """
  """
  alias ShopifyApi.AuthToken
  alias ShopifyApi.Request

  @doc """
    Return a single Product Variant
  """
  def get(%AuthToken{} = auth, variant_id) do
    Request.get(auth, "variants/#{variant_id}.json")
  end

  @doc """
    Return all of a Product's Variants.

    iex> ShopifyApi.ProductVariant.get(token, product_id)

  """
  def all(%AuthToken{} = auth, product_id) do
    Request.get(auth, "products/#{product_id}/variants.json")
  end

  @doc """
    Return a count of all Product Variants.

  iex> ShopifyApi.ProductVariant.get(token, product_id)
  {:ok, %{"count" => integer}}
  """

  def count(%AuthToken{} = auth, product_id) do
    Request.get(auth, "products/#{product_id}/variants/count.json")
  end

  @doc """
    Delete a Product Variant.

  iex> ShopifyApi.Product.delete(token, product_it, variant_id)
  {:ok, %{}}
  """
  def delete(%AuthToken{} = auth, product_id, variant_id) do
    Request.delete(auth, "products/#{product_id}/variants/#{variant_id}.json")
  end

  @doc """
    Create a new Product Variant.

  iex> ShopifyApi.ProductVariant.create(token, product_id, %{variant: %{body_html: "Testing variant create", title: "Testing Create Product Variant"}})
  """
  def create(%AuthToken{} = auth, product_id, %{variant: %{}} = variant) do
    Request.post(auth, "products/#{product_id}/variants.json", variant)
  end

  @doc """
    Update a Product Variant.
  """
  def update(%AuthToken{} = auth, %{variant: %{variant_id: variant_id}} = variant) do
    Request.put(auth, "variants/#{variant_id}.json", variant)
  end
end
