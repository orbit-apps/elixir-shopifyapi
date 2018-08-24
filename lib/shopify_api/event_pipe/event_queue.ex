defmodule ShopifyAPI.EventPipe.EventQueue do
  require Logger
  alias ShopifyAPI.AuthToken

  def enqueue(%{destination: :application} = event),
    do: enqueue_event(ShopifyAPI.EventPipe.ApplicationWorker, event)

  def enqueue(%{destination: :shopify, object: %{fulfillment: %{}}} = event),
    do: enqueue_event(ShopifyAPI.EventPipe.FulfillmentWorker, event)

  def enqueue(%{destination: :shopify, object: %{inventory_level: %{}}} = event),
    do: enqueue_event(ShopifyAPI.EventPipe.InventoryLevelWorker, event)

  def enqueue(%{destination: :shopify, object: %{location: %{}}} = event),
    do: enqueue_event(ShopifyAPI.EventPipe.LocationWorker, event)

  def enqueue(%{destination: :shopify, object: %{metafield: %{}}} = event),
    do: enqueue_event(ShopifyAPI.EventPipe.MetafieldWorker, event)

  def enqueue(%{destination: :shopify, object: %{product: %{}}} = event),
    do: enqueue_event(ShopifyAPI.EventPipe.ProductWorker, event)

  def enqueue(%{destination: :shopify, object: %{transaction: %{}}} = event),
    do: enqueue_event(ShopifyAPI.EventPipe.TransactionWorker, event)

  def enqueue(%{destination: :shopify, object: %{variant: %{}}} = event),
    do: enqueue_event(ShopifyAPI.EventPipe.VariantWorker, event)

  def enqueue(event),
    do:
      Logger.warn(fn ->
        "#{__MODULE__} does not know what worker should handle #{inspect(event)}"
      end)

  defp enqueue_event(worker, %{token: token} = event) do
    Logger.info(fn -> "Enqueueing[#{AuthToken.create_key(token)}] #{inspect(event)}" end)
    Exq.enqueue(Exq, AuthToken.create_key(token), worker, [event])
  end

  defp enqueue_event(worker, event) do
    Logger.warn(fn -> "Enqueueing in default queue #{inspect(event)}" end)
    Exq.enqueue(Exq, "default", worker, [event])
  end

  def register(token) do
    Logger.info(fn -> "#{__MODULE__} registering #{AuthToken.create_key(token)}" end)

    case GenServer.whereis(Exq) do
      nil ->
        :timer.sleep(500)
        register(token)

      _res ->
        Exq.subscribe(Exq, AuthToken.create_key(token), 1)
    end
  end
end
