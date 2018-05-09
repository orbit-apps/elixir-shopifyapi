defmodule ShopifyApi.EventPipe.LoggingEventProcessor do
  @moduledoc """
  Generic event logger, listens to the whole stream and emits logs.
  """
  require Logger
  use GenStage
  alias ShopifyApi.EventPipe.ExternalEventQueue

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
          ExternalEventQueue,
          selector: fn _ -> true end
        }
      ]
    }
  end

  def handle_events(events, _from, state) do
    for event <- events do
      Logger.info("#{__MODULE__} is processing an event")
      Logger.info(inspect(event))
    end

    {:noreply, [], state}
  end
end
