defmodule ShopifyApi.EventPipe.EventQueue do
  require Logger

  def enqueue(%{destination: :shopify, product: _product} = event) do
    Exq.enqueue(Exq, "default", "ShopifyApi.EventPipe.ProductWorker", [event])
  end

  def enqueue(event),
    do: Logger.warn("#{__MODULE__} does not know what worker should handle #{inspect(event)}")
end
