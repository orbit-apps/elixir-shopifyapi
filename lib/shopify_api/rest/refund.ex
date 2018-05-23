defmodule ShopifyApi.Rest.Refund do
  @moduledoc """
  ShopifyApi REST API Refund resource
  """

  alias ShopifyApi.AuthToken
  alias ShopifyApi.Rest.Request

  @doc """
  Return a list of all refunds for an order.

  ## Example

      iex> ShopifyApi.Rest.Refund.all(auth, string)
      {:ok, { "refunds" => [] }}
  """
  def all(%AuthToken{} = auth, order_id) do
    Request.get(auth, "orders/#{order_id}/refunds.json")
  end

  @doc """
  Get a specific refund.

  ## Example

      iex> ShopifyApi.Rest.Refund.get(auth, string, string)
      {:ok, { "refund" => %{} }}
  """
  def get(%AuthToken{} = auth, order_id, refund_id) do
    Request.get(auth, "orders/#{order_id}/refunds/#{refund_id}.json")
  end

  @doc """
  Calculate a refund.

  ## Example

      iex> ShopifyApi.Rest.Refund.calculate(auth, integer)
      {:ok, { "refund" => %{} }}
  """
  def calculate(%AuthToken{} = auth, order_id) do
    Request.post(auth, "orders/#{order_id}/refunds/calculate.json")
  end

  @doc """
  Create a refund.

  ## Example

      iex> ShopifyApi.Rest.Refund.create(auth, integer, map)
      {:ok, { "refund" => %{} }}
  """
  def create(%AuthToken{} = auth, order_id, %{refund: %{}} = refund) do
    Request.post(auth, "orders/#{order_id}/refunds.json", refund)
  end
end
