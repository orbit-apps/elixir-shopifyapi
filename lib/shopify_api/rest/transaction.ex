defmodule ShopifyAPI.REST.Transaction do
  @moduledoc """
  """
  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST

  @doc """
    Return all the Transactions for an Order.
  """
  def all(%AuthToken{} = auth, order_id, params \\ []),
    do: REST.get(auth, "orders/#{order_id}/transactions.json", params)

  def create(%AuthToken{} = auth, %{transaction: %{order_id: order_id}} = transaction),
    do: REST.post(auth, "orders/#{order_id}/transactions.json", transaction)
end
