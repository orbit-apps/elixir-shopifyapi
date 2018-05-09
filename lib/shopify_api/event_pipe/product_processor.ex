defmodule ShopifyApi.EventPipe.ProductProcessor do
  @moduledoc """
  Consumer that listens for Shopify bound events and processes them.
  """
  require Logger
  use GenStage
  alias ShopifyApi.Rest.Product

  @doc "Starts the consumer."
  def start_link() do
    Logger.info("Starting #{__MODULE__}...")
    GenStage.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    # Starts a permanent subscription to the broadcaster
    # which will automatically start requesting items.
    {
      :consumer,
      :ok,
      subscribe_to: [
        {
          ShopifyApi.EventPipe.ExternalEventQueue,
          selector: &do_filter/1
        }
      ]
    }
  end

  def handle_events(events, _from, state) do
    for event <- events do
      Logger.info("#{__MODULE__} is processing an event")
      Logger.info(inspect(event))
      response = case event.action do
        :create ->
          Product.create(event.token, event.product)
        :update ->
          Product.update(event.token, event.product)
      end
      case response do
        {:ok, msg} ->
          Logger.info("Succesful with push #{inspect msg}")
        {:error, errors} ->
          Logger.warn("Enountered an error while pushing product #{inspect errors}")
      end
      event.call_back.(event, response)
    end

    {:noreply, [], state}
  end

  def do_filter(%{destination: :shopify, token: %ShopifyApi.AuthToken{}, product: %{}}), do: true
  def do_filter(_), do: false
end
