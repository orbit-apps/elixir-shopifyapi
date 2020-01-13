defmodule ShopifyAPI.REST.Order do
  @moduledoc """
  """
  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST

  @shopify_per_page_max 250

  @doc """
    Return a single Order.
  """
  def get(%AuthToken{} = auth, order_id), do: REST.get(auth, "orders/#{order_id}.json")

  @doc """
    Return all of a shops Orders filtered by query parameters.

  iex> ShopifyAPI.REST.Order.all(token)
  iex> ShopifyAPI.REST.Order.all(auth, [param1: "value", param2: "value2"])
  """
  def all(%AuthToken{} = auth, params \\ []),
    do: REST.get(auth, "orders.json", params)

  @doc """
    Delete an Order.

  iex> ShopifyAPI.REST.Order.delete(auth, order_id)
  """
  def delete(%AuthToken{} = auth, order_id), do: REST.delete(auth, "orders/#{order_id}.json")

  @doc """
    Create a new Order.

  iex> ShopifyAPI.REST.Order.create(auth, %Order{})
  """
  def create(%AuthToken{} = auth, %{order: %{}} = order),
    do: REST.post(auth, "orders.json", order)

  @doc """
    Update an Order.

  iex> ShopifyAPI.REST.Order.update(auth, order_id)
  """
  def update(%AuthToken{} = auth, %{order: %{id: order_id}} = order),
    do: REST.put(auth, "orders/#{order_id}.json", order)

  @doc """
    Return a count of all Orders.

  iex> ShopifyAPI.REST.Order.get(token)
  {:ok, %{"count" => integer}}
  """
  def count(%AuthToken{} = auth), do: REST.get(auth, "orders/count.json")

  @doc """
    Close an Order.

  iex> ShopifyAPI.REST.Order.close(auth, order_id)
  """
  def close(%AuthToken{} = auth, order_id),
    do: REST.post(auth, "orders/#{order_id}/close.json")

  @doc """
    Re-open a closed Order.

  iex> ShopifyAPI.REST.Order.open(auth, order_id)
  """
  def open(%AuthToken{} = auth, order_id), do: REST.post(auth, "orders/#{order_id}/open.json")

  @doc """
    Cancel an Order.

  iex> ShopifyAPI.REST.Order.cancel(auth, order_id)
  """
  def cancel(%AuthToken{} = auth, order_id),
    do: REST.post(auth, "orders/#{order_id}/cancel.json")

  def max_per_page, do: @shopify_per_page_max
end
