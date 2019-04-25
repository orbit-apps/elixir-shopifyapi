defmodule ShopifyAPI.EventPipe.InlineBackgroundJob do
  @behaviour ShopifyAPI.EventPipe.BackgroundJobBehaviour

  def enqueue(_queue_name, worker, events, _opts) do
    events
    |> Enum.each(fn event -> worker.perform(event) end)
  end
end
