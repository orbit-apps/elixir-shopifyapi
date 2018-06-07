defmodule ShopifyAPI.EventPipe.EventQueue do
  require Logger

  def enqueue(%{destination: :shopify, object: %{product: %{}}} = event) do
    Logger.info("Enqueueing #{inspect(event)}")
    Toniq.enqueue(ShopifyAPI.EventPipe.ProductWorker, event)
  end

  def enqueue(event),
    do: Logger.warn("#{__MODULE__} does not know what worker should handle #{inspect(event)}")
end
