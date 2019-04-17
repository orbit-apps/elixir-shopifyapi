defmodule ShopifyAPI.REST.Customer do
  @moduledoc """
  Shopify REST API Customer resource
  """

  require Logger
  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST.Request

  @doc """
  Returns all the customers.

  ## Example

      iex> ShopifyAPI.REST.Customer.all(auth)
      {:ok, {"customers" => []}
  """
  def all(%AuthToken{} = auth), do: Request.get(auth, "customers.json")

  @doc """
  Return a single customer.

  ## Example

      iex> ShopifyAPI.REST.Customer.get(auth, integer)
      {:ok, {"customer" = > %{}}
  """
  def get(%AuthToken{} = auth, customer_id),
    do: Request.get(auth, "customers/#{customer_id}.json")

  @doc """
  Return a customers that match supplied query.

  NOTE: Not implemented.

  ## Example

      iex> ShopifyAPI.REST.Customer.getQuery()
      {:error, "Not implemented"}
  """
  def get_query do
    Logger.warn("#{__MODULE__} error, resource not implemented.")
    {:error, "Not implemented"}
  end

  @doc """
  Creates a customer.

  ## Example

      iex> ShopifyAPI.REST.Customer.create(auth, map)
      {:ok, {"customer" => %{}}
  """
  def create(%AuthToken{} = auth, %{customer: %{}} = customer),
    do: Request.post(auth, "customers.json", customer)

  @doc """
  Updates a customer.

  ## Example

      iex> ShopifyAPI.REST.Customer.update(auth, map)
      {:ok, {"customer" => %{}}
  """
  def update(%AuthToken{} = auth, %{customer: %{id: customer_id}} = customer),
    do: Request.put(auth, "customers/#{customer_id}.json", customer)

  @doc """
  Create an account activation URL.

  ## Example

      iex> ShopifyAPI.REST.Customer.CreateActivationUrl(auth, integer)
      {:ok, {"account_activation_url" => "" }
  """
  def create_activation_url(
        %AuthToken{} = auth,
        %{customer: %{id: customer_id}} = customer
      ),
      do: Request.post(auth, "customers/#{customer_id}/account_activation.json", customer)

  @doc """
  Send an account invite to customer.

  ## Example

      iex> ShopifyAPI.REST.Customer.sendInvite(auth, integer)
      {:ok, {"customer_invite" => %{}}
  """
  def send_invite(%AuthToken{} = auth, customer_id),
    do: Request.post(auth, "customers/#{customer_id}/send_invite.json")

  @doc """
  Delete a customer.

  ## Example

      iex> ShopifyAPI.REST.Customer.delete(auth, integer)
      {:ok, 200 }
  """
  def delete(%AuthToken{} = auth, customer_id),
    do: Request.delete(auth, "customers/#{customer_id}")

  @doc """
  Return a count of all customers.

  ## Example

      iex> ShopifyAPI.REST.Customer.count(auth)
      {:ok, {"count" => integer }}
  """
  def count(%AuthToken{} = auth), do: Request.get(auth, "customers/count.json")

  @doc """
  Return all orders from a customer.

  ## Example

      iex> ShopifyAPI.REST.Customer.GetOrder(auth, integer)
      {:ok, {"orders" => [] }}
  """
  def get_orders(%AuthToken{} = auth, customer_id),
    do: Request.get(auth, "customers/#{customer_id}/orders.json")

  @doc """
  Search for customers that match a supplied query

  ## Example

      iex> ShopifyAPI.REST.Customer.search(auth, params)
      {:ok, {"customers" => [] }}

  The search params must be passed in as follows:
  %{"query" => "store::7020"} - returns all customers with a tag of store::7020
  %{"query" => "country:Canada"} - returns all customers with an address in Canada
  %{"query" => "Bob country:Canada"} - returns all customers with an address in Canada and the name "Bob"
  """
  def search(%AuthToken{} = auth, params),
    do: Request.get(auth, "customers/search.json?" <> URI.encode_query(params))
end
