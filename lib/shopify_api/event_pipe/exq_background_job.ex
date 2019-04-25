defmodule ShopifyAPI.EventPipe.ExqBackgroundJob do
  @behaviour ShopifyAPI.EventPipe.BackgroundJobBehaviour

  def enqueue(queue_name, worker, events, opts) do
    Exq.enqueue(Exq, queue_name, worker, events, opts)
  end
end
