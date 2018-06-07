defmodule ShopifyApi.Rest.Customer do
  @moduledoc """
  Shopify REST API Customer resource
  """

  require Logger
  alias ShopifyApi.AuthToken
  alias ShopifyApi.Rest.Request

  @doc """
  Returns all the customers.

  ## Example

      iex> ShopifyApi.Rest.Customer.all(auth)
      {:ok, {"customers" => []}
  """
  def all(%AuthToken{} = auth) do
    Request.get(auth, "customers.json")
  end

  @doc """
  Return a single customer.

  ## Example

      iex> ShopifyApi.Rest.Customer.get(auth, integer)
      {:ok, {"customer" = > %{}}
  """
  def get(%AuthToken{} = auth, customer_id) do
    Request.get(auth, "customers/#{customer_id}.json")
  end

  @doc """
  Return a customers that match supplied query.

  NOTE: Not implemented.

  ## Example

      iex> ShopifyApi.Rest.Customer.getQuery()
      {:error, "Not implemented"}
  """
  def get_query do
    Logger.warn("#{__MODULE__} error, resource not implemented.")
    {:error, "Not implemented"}
  end

  @doc """
  Creates a customer.

  ## Example

      iex> ShopifyApi.Rest.Customer.create(auth, map)
      {:ok, {"customer" => %{}}
  """
  def create(%AuthToken{} = auth, %{customer: %{}} = customer) do
    Request.post(auth, "customers.json", customer)
  end

  @doc """
  Updates a customer.

  ## Example

      iex> ShopifyApi.Rest.Customer.update(auth, map)
      {:ok, {"customer" => %{}}
  """
  def update(%AuthToken{} = auth, %{customer: %{id: customer_id}} = customer) do
    Request.put(auth, "customers/#{customer_id}.json", customer)
  end

  @doc """
  Create an account activation URL.

  ## Example

      iex> ShopifyApi.Rest.Customer.CreateActivationUrl(auth, integer)
      {:ok, {"account_activation_url" => "" }
  """
  def create_activation_url(
        %AuthToken{} = auth,
        %{customer: %{id: customer_id}} = customer
      ) do
    Request.post(auth, "customers/#{customer_id}/account_activation.json", customer)
  end

  @doc """
  Send an account invite to customer.

  ## Example

      iex> ShopifyApi.Rest.Customer.sendInvite(auth, integer)
      {:ok, {"customer_invite" => %{}}
  """
  def send_invite(%AuthToken{} = auth, customer_id) do
    Request.post(auth, "customers/#{customer_id}/send_invite.json")
  end

  @doc """
  Delete a customer.

  ## Example

      iex> ShopifyApi.Rest.Customer.delete(auth, integer)
      {:ok, 200 }
  """
  def delete(%AuthToken{} = auth, customer_id) do
    Request.delete(auth, "customers/#{customer_id}")
  end

  @doc """
  Return a count of all customers.

  ## Example

      iex> ShopifyApi.Rest.Customer.count(auth)
      {:ok, {"count" => integer }}
  """
  def count(%AuthToken{} = auth) do
    Request.get(auth, "customers/count.json")
  end

  @doc """
  Return all orders from a customer.

  ## Example

      iex> ShopifyApi.Rest.Customer.GetOrder(auth, integer)
      {:ok, {"orders" => [] }}
  """
  def get_orders(%AuthToken{} = auth, customer_id) do
    Request.get(auth, "customers/#{customer_id}/orders.json")
  end
end
