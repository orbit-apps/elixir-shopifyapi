defmodule ShopifyAPI.EventPipe.ExqBackgroundJob do
  require Logger

  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.EventPipe.BackgroundJobBehaviour

  @behaviour BackgroundJobBehaviour

  @retry_timer 250

  @impl BackgroundJobBehaviour
  def subscribe(token) do
    case GenServer.whereis(Exq) do
      nil ->
        :timer.sleep(@retry_timer)
        subscribe(token)

      _res ->
        Logger.info(fn -> "#{__MODULE__} registering #{AuthToken.create_key(token)}" end)
        Exq.subscribe(Exq, AuthToken.create_key(token), 1)
    end
  end

  @impl BackgroundJobBehaviour
  def enqueue(queue_name, worker, events, opts) do
    Exq.enqueue(Exq, queue_name, worker, events, opts)
  end
end
