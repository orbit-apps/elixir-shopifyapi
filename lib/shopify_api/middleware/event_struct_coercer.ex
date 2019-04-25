defmodule ShopifyAPI.Middleware.EventStructCoercer do
  @moduledoc """
  Takes in an event and turns it into a struct. Allows for better typing on workers.
  """

  @behaviour Exq.Middleware.Behaviour

  alias Exq.Middleware.Pipeline
  alias ShopifyAPI.EventPipe.Event

  def before_work(%Pipeline{assigns: %{job: %{args: args} = job}} = pipeline) do
    events = Enum.map(args, &into_event_if_fits/1)

    Pipeline.assign(pipeline, :job, %{job | args: events})
  end

  defp into_event_if_fits(%{destination: _, action: _, token: _} = event) do
    has_extra_keys =
      event
      |> Map.keys()
      |> Enum.find(false, fn key -> not Map.has_key?(%Event{}, key) end)

    if has_extra_keys do
      event
    else
      struct(Event, event)
    end
  end

  defp into_event_if_fits(event), do: event

  def after_processed_work(pipeline), do: pipeline
  def after_failed_work(pipeline), do: pipeline
end
