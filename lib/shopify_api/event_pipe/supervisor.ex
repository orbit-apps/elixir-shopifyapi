defmodule ShopifyApi.EventPipe.Supervisor do
  require Logger
  use Supervisor
  alias ShopifyApi.EventPipe.{ExternalEventQueue, ProductProcessor, LoggingEventProcessor}

  def start_link(opts) do
    Logger.info("Starting #{__MODULE__}...")
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_) do
    Supervisor.init(
      [
        supervisor(ExternalEventQueue, []),
        supervisor(ProductProcessor, [])
#supervisor(LoggingEventProcessor, [])
      ],
      strategy: :one_for_one
    )
  end
end
