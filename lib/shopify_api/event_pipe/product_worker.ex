defmodule ShopifyAPI.EventPipe.ProductWorker do
  @moduledoc """
  Worker for processing Products
  """
  require Logger
  import ShopifyAPI.EventPipe.Worker
  alias ShopifyAPI.EventPipe.Event
  alias ShopifyAPI.REST.Product

  def perform(%Event{action: "create", object: _, token: _} = event),
    do: execute_action(event, fn token, %{object: product} -> Product.create(token, product) end)

  def perform(%Event{action: "update", object: _, token: _} = event),
    do: execute_action(event, fn token, %{object: product} -> Product.update(token, product) end)

  def perform(%Event{action: "get", object: _, token: _} = event),
    do:
      execute_action(event, fn token, %{object: %{product: %{id: id}}} ->
        Product.get(token, id)
      end)
end
