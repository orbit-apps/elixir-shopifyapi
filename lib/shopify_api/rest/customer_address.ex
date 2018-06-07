defmodule ShopifyApi.Rest.CustomerAddress do
  @moduledoc """
  Shopify REST API Customer Address resources.
  """

  require Logger
  alias ShopifyApi.AuthToken
  alias ShopifyApi.Rest.Request

  @doc """
  Return a list of all addresses for a customer.

  ## Example

      iex> ShopifyApi.Rest.CustomerAddress.all(auth, string)
      {:ok, %{ "addresses" => [] }}
  """
  def all(%AuthToken{} = auth, customer_id) do
    Request.get(auth, "customers/#{customer_id}/addresses.json")
  end

  @doc """
  Return a single address for a customer.

  ## Example

      iex> ShopifyApi.Rest.CustomerAddress.get(auth, string, string)
      {:ok, %{ "customer_address" => %{} }}
  """
  def get(%AuthToken{} = auth, customer_id, address_id) do
    Request.get(auth, "customers/#{customer_id}/addresses/#{address_id}.json")
  end

  @doc """
  Create a new address for a customer.

  ## Example

      iex> ShopifyApi.Rest.CustomerAddress.create(auth, string, map)
      {:ok, %{ "customer_address" => %{} }}
  """
  def create(%AuthToken{} = auth, customer_id, %{address: %{}} = address) do
    Request.post(auth, "customers/#{customer_id}/addresses.json", address)
  end

  @doc """
  Update an existing customer address.

  ## Example

      iex> ShopifyApi.Rest.CustomerAddress.update(auth, string, string)
      {:ok, %{ "customer_address" => %{} }}
  """
  def update(
        %AuthToken{} = auth,
        customer_id,
        %{address: %{id: address_id}} = address
      ) do
    Request.put(
      auth,
      "customers/#{customer_id}/addresses/#{address_id}.json",
      address
    )
  end

  @doc """
  Delete an address from a customers address list.

  ## Example

      iex> ShopifyApi.Rest.CustomerAddress.delete(auth, string, string)
      {:ok, 200 }
  """
  def delete(%AuthToken{} = auth, customer_id, address_id) do
    Request.delete(auth, "customers/#{customer_id}/addresses/#{address_id}.json")
  end

  @doc """
  Perform bulk operations for multiple customer addresses.

  NOTE: Not implemented.

  ## Example

      iex> ShopifyApi.Rest.CustomerAddress.action()
      {:error, "Not implemented" }
  """
  def action do
    Logger.warn("#{__MODULE__} error, resource not implemented.")
    {:error, "Not implemented"}
  end

  @doc """
  Set the default address for a customer.

  ## Example

      iex> ShopifyApi.Rest.CustomerAddress.setDefault(auth, string, string)
      {:ok, %{ "customer_address" => %{} }}
  """
  def set_default(
        %AuthToken{} = auth,
        customer_id,
        %{address: %{id: address_id}} = address
      ) do
    Request.put(
      auth,
      "customers/#{customer_id}/addresses/#{address_id}/default.json",
      address
    )
  end
end
