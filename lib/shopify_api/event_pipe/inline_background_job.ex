defmodule ShopifyAPI.EventPipe.InlineBackgroundJob do
  alias ShopifyAPI.EventPipe.BackgroundJobBehaviour
  @behaviour BackgroundJobBehaviour

  @impl BackgroundJobBehaviour
  def subscribe(_token), do: nil

  @impl BackgroundJobBehaviour
  def enqueue(_queue_name, worker, events, _opts) do
    events
    |> Enum.each(fn event -> worker.perform(event) end)
  end
end
