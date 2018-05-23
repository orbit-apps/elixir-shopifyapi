defmodule ShopifyApi.Rest.FulfillmentEvent do
  @moduledoc """
  ShopifyApi REST API FulfillmentEvent resource
  """

  alias ShopifyApi.AuthToken
  alias ShopifyApi.Rest.Request

  @doc """
  Return a list of all fulfillment events.

  ## Example

      iex> ShopifyApi.Rest.FulfillmentEvent.all(auth, string, string)
      {:ok, { "fulfillment_events" => [] }}
  """
  def all(%AuthToken{} = auth, order_id, fulfillment_id) do
    Request.get(auth, "orders/#{order_id}/fulfillments/#{fulfillment_id}/events.json")
  end

  @doc """
  Get a single fulfillment event.

  ## Example

      iex> ShopifyApi.Rest.FulfillmentEvent.get(auth, string, string, string)
      {:ok, { "fulfillment_event" => %{} }}
  """
  def get(%AuthToken{} = auth, order_id, fulfillment_id, event_id) do
    Request.get(auth, "orders/#{order_id}/fulfillments/#{fulfillment_id}/events/#{event_id}.json")
  end

  @doc """
  Create a new fulfillment event.

  ## Example

      iex> ShopifyApi.Rest.FulfillmentEvent.post(auth, map)
      {:ok, { "fulfillment_event" => %{} }}
  """
  def post(
        %AuthToken{} = auth,
        order_id,
        %{fulfillment_event: %{id: fulfillment_id}} = fulfillment_event
      ) do
    Request.post(
      auth,
      "orders/#{order_id}/fulfillments/#{fulfillment_id}/events.json",
      fulfillment_event
    )
  end

  @doc """
  Delete a fulfillment event.

  ## Example

      iex> ShopifyApi.Rest.FulfillmentEvent.delete(auth, string, string, string)
      {:ok,  200 }
  """
  def delete(%AuthToken{} = auth, order_id, fulfillment_id, event_id) do
    Request.delete(
      auth,
      "orders/#{order_id}/fulfillments/#{fulfillment_id}/events/#{event_id}.json"
    )
  end
end
