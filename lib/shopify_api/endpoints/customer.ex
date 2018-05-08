defmodule ShopifyApi.Customer do
  @moduledoc """
    Shopify REST API Customer endpoint
  """

  alias ShopifyApi.AuthToken
  alias ShopifyApi.Request

  @doc """
    Returns all the customers.
  """
  def all(%AuthToken{} = auth) do
    Request.get(auth, "customers.json")
  end

  @doc """
    Return a single customer.
  """
  def get(%AuthToken{} = auth, customer_id) do
    Request.get(auth, "customers/#{customer_id}.json")
  end

  @doc """
    Return a customers that match supplied query.
  """
  def get_query(%AuthToken{} = auth, %{query: []} = query) do
    Request.get(auth, "customers/search.json?query=#{query}")
  end

  @doc """
    Creates a customer.
  """
  def create(%AuthToken{} = auth, %{customer: %{}} = customer) do
    Request.post(auth, "customers.json", customer)
  end

  @doc """
    Updates a customer.
  """
  def update(%AuthToken{} = auth, %{customer: %{}} = customer) do
    Request.put(auth, "customers/#{customer_id}.json", customer)
  end

  @doc """
    Create an account activiation URL.
  """
  def create_activiation(%AuthToken{} = auth, customer_id) do
    Request.post(auth, "customers/#{customer_id}/account_activation.json")
  end

  @doc """
    Send an account invite to customer.
  """
  def send_invite(%AuthToken{} = auth, customer_id) do
    Request.post(auth, "customers/#{customer_id}/send_invite.json")
  end

  @doc """
    Delete a customer.
  """
  def delete(%AuthToken{} = auth, customer_id) do
    Request.delete(auth, "customers/#{customer_id}")
  end

  @doc """
    Return a count of all customers.
  """
  def count(%AuthToken{} = auth) do
    Request.get(auth, "customers/count.json")
  end

  @doc """
    Return all orders from a customer.
  """
  def get_order(%AuthToken{} = auth, customer_id) do
    Request.get(auth, "customers/#{customer_id}/orders.json")
  end
end
