defmodule ShopifyAPI.REST.Order do
  @moduledoc """
  """
  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST.Request

  @doc """
    Return a single Order.
  """
  def get(%AuthToken{} = auth, order_id) do
    Request.get(auth, "orders/#{order_id}.json")
  end

  @doc """
    Return all of a shops Orders.

  iex> ShopifyAPI.REST.Order.all(token)
  """
  def all(%AuthToken{} = auth) do
    Request.get(auth, "orders.json")
  end

  @doc """
    Delete an Order.

  iex> ShopifyAPI.REST.Order.delete(token, order_id)
  """
  def delete(%AuthToken{} = auth, order_id) do
    Request.delete(auth, "orders/#{order_id}.json")
  end

  @doc """
    Create a new Order.

  iex> ShopifyAPI.REST.Order.create(token, %Order{})
  """
  def create(%AuthToken{} = auth, %{order: %{}} = order) do
    Request.post(auth, "orders.json", order)
  end

  @doc """
    Update an Order.

  iex> ShopifyAPI.REST.Order.update(token, order_id)
  """
  def update(%AuthToken{} = auth, %{order: %{order_id: order_id}} = order) do
    Request.put(auth, "orders/#{order_id}.json", order)
  end

  @doc """
    Return a count of all Orders.

  iex> ShopifyAPI.REST.Order.get(token)
  {:ok, %{"count" => integer}}
  """
  def count(%AuthToken{} = auth) do
    Request.get(auth, "orders/count.json")
  end

  @doc """
    Close an Order.

  iex> ShopifyAPI.REST.Order.close(token, order_id)
  """
  def close(%AuthToken{} = auth, order_id) do
    Request.post(auth, "orders/#{order_id}/close.json")
  end

  @doc """
    Re-open a closed Order.

  iex> ShopifyAPI.REST.Order.open(token, order_id)
  """
  def open(%AuthToken{} = auth, order_id) do
    Request.post(auth, "orders/#{order_id}/open.json")
  end

  @doc """
    Cancel an Order.

  iex> ShopifyAPI.REST.Order.cancel(token, order_id)
  """
  def cancel(%AuthToken{} = auth, order_id) do
    Request.post(auth, "orders/#{order_id}/cancel.json")
  end
end
