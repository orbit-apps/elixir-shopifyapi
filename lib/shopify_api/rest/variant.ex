defmodule ShopifyAPI.REST.Variant do
  @moduledoc """
  """
  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST.Request

  @doc """
    Return a single Product Variant
  """
  def get(%AuthToken{} = auth, variant_id), do: Request.get(auth, "variants/#{variant_id}.json")

  @doc """
    Return all of a Product's Variants.

    iex> ShopifyAPI.REST.Variant.get(auth, product_id)

  """
  def all(%AuthToken{} = auth, product_id),
    do: Request.get(auth, "products/#{product_id}/variants.json")

  @doc """
    Return a count of all Product Variants.

  iex> ShopifyAPI.REST.Variant.get(auth, product_id)
  {:ok, %{"count" => integer}}
  """

  def count(%AuthToken{} = auth, product_id),
    do: Request.get(auth, "products/#{product_id}/variants/count.json")

  @doc """
    Delete a Product Variant.

  iex> ShopifyAPI.REST.Variant.delete(auth, product_id, variant_id)
  {:ok, %{}}
  """
  def delete(%AuthToken{} = auth, product_id, variant_id),
    do: Request.delete(auth, "products/#{product_id}/variants/#{variant_id}.json")

  @doc """
    Create a new Product Variant.

  iex> ShopifyAPI.REST.Variant.create(auth, product_id, %{variant: %{body_html: "Testing variant create", title: "Testing Create Product Variant"}})
  """
  def create(%AuthToken{} = auth, product_id, %{variant: %{}} = variant),
    do: Request.post(auth, "products/#{product_id}/variants.json", variant)

  @doc """
    Update a Product Variant.
  """
  def update(%AuthToken{} = auth, %{variant: %{id: variant_id}} = variant),
    do: Request.put(auth, "variants/#{variant_id}.json", variant)
end
