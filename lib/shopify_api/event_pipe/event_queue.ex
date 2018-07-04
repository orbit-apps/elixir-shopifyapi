defmodule ShopifyAPI.EventPipe.EventQueue do
  require Logger

  def enqueue(%{destination: :shopify, object: %{product: %{}}} = event) do
    Logger.info(fn -> "Enqueueing #{inspect(event)}" end)
    Exq.enqueue(Exq, "outbound", ShopifyAPI.EventPipe.ProductWorker, [event])
  end

  def enqueue(%{destination: :shopify, object: %{variant: %{}}} = event) do
    Logger.info(fn -> "Enqueueing #{inspect(event)}" end)
    Exq.enqueue(Exq, "outbound", ShopifyAPI.EventPipe.VariantWorker, [event])
  end

  def enqueue(%{destination: :shopify, object: %{inventory_level: %{}}} = event) do
    Logger.info(fn -> "Enqueueing #{inspect(event)}" end)
    Exq.enqueue(Exq, "outbound", ShopifyAPI.EventPipe.InventoryLevelWorker, [event])
  end

  def enqueue(%{destination: :shopify, object: %{location: %{}}} = event) do
    Logger.info(fn -> "Enqueueing #{inspect(event)}" end)
    Exq.enqueue(Exq, "outbound", ShopifyAPI.EventPipe.LocationWorker, [event])
  end

  def enqueue(event),
    do: Logger.warn("#{__MODULE__} does not know what worker should handle #{inspect(event)}")
end
