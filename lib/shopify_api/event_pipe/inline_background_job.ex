defmodule ShopifyAPI.EventPipe.InlineBackgroundJob do
  require Logger
  alias ShopifyAPI.EventPipe.BackgroundJobBehaviour
  @behaviour BackgroundJobBehaviour

  @impl BackgroundJobBehaviour
  def subscribe(_token), do: nil

  @impl BackgroundJobBehaviour
  def enqueue(_queue_name, worker, events, _opts) do
    Enum.each(events, fn event -> worker.perform(event) end)
  end

  @impl BackgroundJobBehaviour
  def fire_callback(%{callback: callback} = event) when is_binary(callback) do
    Logger.info(fn -> "Firing call back to #{callback} with #{inspect(event)}" end)
    {func, _} = Code.eval_string(callback)
    func.(event)

    {:ok, "Callback fired"}
  end

  def fire_callback(%{callback: callback}) when is_nil(callback),
    do: {:ok, "no callback to call"}
end
