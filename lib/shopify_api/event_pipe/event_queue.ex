defmodule ShopifyAPI.EventPipe.EventQueue do
  require Logger

  def enqueue(%{destination: :shopify, object: %{product: %{}}} = event) do
    enqueue_event(ShopifyAPI.EventPipe.ProductWorker, event)
  end

  def enqueue(%{destination: :shopify, object: %{variant: %{}}} = event) do
    enqueue_event(ShopifyAPI.EventPipe.VariantWorker, event)
  end

  def enqueue(%{destination: :shopify, object: %{inventory_level: %{}}} = event) do
    enqueue_event(ShopifyAPI.EventPipe.InventoryLevelWorker, event)
  end

  def enqueue(%{destination: :shopify, object: %{location: %{}}} = event) do
    enqueue_event(ShopifyAPI.EventPipe.LocationWorker, event)
  end

  def enqueue(%{destination: :shopify, object: %{metafield: %{}}} = event) do
    enqueue_event(ShopifyAPI.EventPipe.MetafieldWorker, event)
  end

  def enqueue(event),
    do: Logger.warn("#{__MODULE__} does not know what worker should handle #{inspect(event)}")

  defp enqueue_event(worker, event) do
    Logger.info(fn -> "Enqueueing #{inspect(event)}" end)
    Exq.enqueue(Exq, "outbound", worker, [event])
  end
end
