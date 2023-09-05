defmodule ShopifyAPI.REST.CustomerAddress do
  @moduledoc """
  Shopify REST API Customer Address resources.
  """

  require Logger
  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST

  @doc """
  Return a list of all addresses for a customer.

  ## Example

      iex> ShopifyAPI.REST.CustomerAddress.all(auth, string)
      {:ok, [%{}, ...] = addresses}
  """
  def all(%AuthToken{} = auth, customer_id, params \\ [], options \\ []),
    do: REST.get(auth, "customers/#{customer_id}/addresses.json", params, options)

  @doc """
  Return a single address for a customer.

  ## Example

      iex> ShopifyAPI.REST.CustomerAddress.get(auth, string, string)
      {:ok, %{} = customer_address}
  """
  def get(%AuthToken{} = auth, customer_id, address_id, params \\ [], options \\ []),
    do:
      REST.get(
        auth,
        "customers/#{customer_id}/addresses/#{address_id}.json",
        params,
        Keyword.merge([pagination: :none], options)
      )

  @doc """
  Create a new address for a customer.

  ## Example

      iex> ShopifyAPI.REST.CustomerAddress.create(auth, string, map)
      {:ok, %{} = customer_address}
  """
  def create(%AuthToken{} = auth, customer_id, %{address: %{}} = address),
    do: REST.post(auth, "customers/#{customer_id}/addresses.json", address)

  @doc """
  Update an existing customer address.

  ## Example

      iex> ShopifyAPI.REST.CustomerAddress.update(auth, string, string)
      {:ok, %{} = customer_address}
  """
  def update(
        %AuthToken{} = auth,
        customer_id,
        %{address: %{id: address_id}} = address
      ) do
    REST.put(
      auth,
      "customers/#{customer_id}/addresses/#{address_id}.json",
      address
    )
  end

  @doc """
  Delete an address from a customers address list.

  ## Example

      iex> ShopifyAPI.REST.CustomerAddress.delete(auth, string, string)
      {:ok, 200 }
  """
  def delete(%AuthToken{} = auth, customer_id, address_id),
    do: REST.delete(auth, "customers/#{customer_id}/addresses/#{address_id}.json")

  @doc """
  Perform bulk operations for multiple customer addresses.

  NOTE: Not implemented.

  ## Example

      iex> ShopifyAPI.REST.CustomerAddress.action()
      {:error, "Not implemented" }
  """
  def action do
    Logger.warning("#{__MODULE__} error, resource not implemented.")
    {:error, "Not implemented"}
  end

  @doc """
  Set the default address for a customer.

  ## Example

      iex> ShopifyAPI.REST.CustomerAddress.setDefault(auth, string, string)
      {:ok, %{} = customer_address}
  """
  def set_default(
        %AuthToken{} = auth,
        customer_id,
        %{address: %{id: address_id}} = address
      ) do
    REST.put(
      auth,
      "customers/#{customer_id}/addresses/#{address_id}/default.json",
      address
    )
  end
end
