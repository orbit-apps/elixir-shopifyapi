defmodule ShopifyAPI.REST.Transaction do
  @moduledoc """
  """
  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST.Request

  @doc """
    Return all the Transactions for an Order.
  """
  def all(%AuthToken{} = auth, order_id) do
    Request.get(auth, "orders/#{order_id}/transactions.json")
  end
end
