defmodule ShopifyAPI.EventPipe.FulfillmentWorker do
  @moduledoc """
  Worker for processing Fulfillments
  """
  import ShopifyAPI.EventPipe.Worker
  alias ShopifyAPI.REST.Fulfillment

  def perform(%{action: "create", object: _, token: _} = event) do
    execute_action(event, fn token,
                             %{object: %{fulfillment: %{order_id: order_id}} = fulfillment} ->
      Fulfillment.create(token, order_id, fulfillment)
    end)
  end
end
