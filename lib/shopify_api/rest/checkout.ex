defmodule ShopifyAPI.REST.Checkout do
  @moduledoc """
  Shopify REST API Checkout resources.
  """

  require Logger
  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST

  @doc """
  Return a single checkout resource.

  ## Example

      iex> ShopifyAPI.REST.Checkout.get(auth, string)
      {:ok, %{} = checkout}
  """
  def get(%AuthToken{} = auth, checkout_token, options \\ []) do
    REST.get(
      auth,
      "checkouts/#{checkout_token}.json",
      [],
      Keyword.merge([pagination: :none], options)
    )
  end

  @doc """
  Create a new checkout for a customer.

  ## Example

      iex> ShopifyAPI.REST.Checkout.create(auth, map)
      {:ok, %{} = checkout}
  """
  def create(%AuthToken{} = auth, %{checkout: %{}} = checkout),
    do: REST.post(auth, "checkouts.json", checkout)

  @doc """
  Update an existing checkout.

  ## Example

      iex> ShopifyAPI.REST.Checkout.update(auth, map)
      {:ok, %{} = checkout}
  """
  def update(%AuthToken{} = auth, %{checkout: %{id: checkout_token}} = checkout) do
    REST.put(auth, "checkouts/#{checkout_token}.json", checkout)
  end

  @doc """
  Completes an existing checkout.

  ## Example

      iex> ShopifyAPI.REST.Checkout.complete(auth, string)
      {:ok, %{} = checkout}
  """
  def complete(%AuthToken{} = auth, checkout_token) do
    REST.post(auth, "checkouts/#{checkout_token}/complete.json", %{})
  end

  @doc """
  Gets shipping rates for a checkout.

  ## Example

      iex> ShopifyAPI.REST.Checkout.shipping_rates(auth, string)
      {:ok, %{"shipping_rates" => [] = shipping_rates}}
  """
  def shipping_rates(%AuthToken{} = auth, checkout_token) do
    REST.get(auth, "checkouts/#{checkout_token}/shipping_rates.json")
  end
end
