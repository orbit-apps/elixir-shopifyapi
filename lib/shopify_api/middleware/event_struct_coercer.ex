defmodule ShopifyAPI.Middleware.EventStructCoercer do
  @moduledoc """
  Takes in an event and turns it into a struct. Allows for better typing on workers.
  """

  @behaviour Exq.Middleware.Behaviour

  alias Exq.Middleware.Pipeline
  alias ShopifyAPI.EventPipe.Event

  def before_work(%Pipeline{assigns: %{job: %{args: args} = job}} = pipeline) do
    events =
      Enum.map(args, fn
        %{description: _, action: _, token: _} = event -> struct(Event, event)
        non_event -> non_event
      end)

    Pipeline.assign(pipeline, :job, %{job | args: events})
  end

  def after_processed_work(pipeline), do: pipeline
  def after_failed_work(pipeline), do: pipeline
end
