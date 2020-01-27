defmodule ShopifyAPI.EventPipe.EventQueue do
  require Logger
  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.EventPipe.Event

  @doc """
  Event enqueue end point, takes the event and the options to be passed on to Exq.

  options: [max_retries: #] or any Exq valid enqueue option.
  """
  @spec enqueue(Event.t(), keyword()) :: {:ok} | {:error, String.t()}
  def enqueue(event, opts \\ [])

  def enqueue(%Event{destination: "application"} = event, opts),
    do: enqueue_event(ShopifyAPI.EventPipe.ApplicationWorker, event, opts)

  def enqueue(%Event{destination: "shopify", object: %{location: %{}}} = event, opts),
    do: enqueue_event(ShopifyAPI.EventPipe.LocationWorker, event, opts)

  def enqueue(event, _opts) do
    Logger.warn(fn ->
      "#{__MODULE__} does not know what worker should handle #{inspect(event)}"
    end)

    {:error, "No worker to handle this event"}
  end

  defp enqueue_event(worker, %{token: %AuthToken{} = token} = event, opts) do
    Logger.info(fn -> "Enqueueing[#{inspect(token)}] #{inspect(event)}" end)
    background_job_impl().enqueue(AuthToken.create_key(token), worker, [event], opts)
    {:ok}
  end

  defp enqueue_event(_worker, %{token: token} = _event, _) do
    Logger.error(fn -> "Unable to create token from #{inspect(token)}" end)
    {:error, "Token needs to be an AuthToken.t"}
  end

  defp enqueue_event(worker, event, opts) do
    Logger.warn(fn -> "Enqueueing in default queue #{inspect(event)}" end)
    background_job_impl().enqueue("default", worker, [event], opts)
    {:ok}
  end

  def fire_callback(%Event{} = event) do
    background_job_impl().fire_callback(event)
  end

  def subscribe(token) do
    background_job_impl().subscribe(token)
  end

  defp background_job_impl do
    Application.get_env(
      :shopify_api,
      :background_job_implementation,
      ShopifyAPI.EventPipe.InlineBackgroundJob
    )
  end
end
