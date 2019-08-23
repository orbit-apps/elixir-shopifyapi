defmodule ShopifyAPI.EventPipe.Logging do
  @moduledoc """
  Applies the metadata stored in the Event to the Logger's metadata.
  """
  require Logger

  alias ShopifyAPI.EventPipe.Event

  def log_metadata(%Event{metadata: metadata} = event) do
    metadata
    |> Enum.into([])
    |> Logger.metadata()

    Logger.info(fn -> "#{__MODULE__} is processing an event: #{inspect(event)}" end)
  end
end
