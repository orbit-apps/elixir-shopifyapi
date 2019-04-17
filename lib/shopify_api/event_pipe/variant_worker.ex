defmodule ShopifyAPI.EventPipe.VariantWorker do
  @moduledoc """
  Worker for processing Variants
  """
  require Logger
  import ShopifyAPI.EventPipe.Worker
  alias ShopifyAPI.EventPipe.Event
  alias ShopifyAPI.REST.Variant

  def perform(%Event{action: "create", object: _, token: _} = event) do
    execute_action(event, fn token, %{object: %{variant: %{product_id: product_id}} = variant} ->
      Variant.create(token, product_id, variant)
    end)
  end

  def perform(%Event{action: "update", object: _, token: _} = event),
    do: execute_action(event, fn token, %{object: variant} -> Variant.update(token, variant) end)
end
