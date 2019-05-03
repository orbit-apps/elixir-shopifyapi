defmodule ShopifyAPI.EventPipe.BackgroundJobBehaviour do
  @moduledoc """
  Defines what an implementation for a background job handler can be.

  By default Exq will be used and needs to be configured.

  You can set the implmentation with `Applicaiton.set_env(:shopify_api, :background_job_implementation, MyImplementation)`

  The implementation is respnsible for calling `worker.perform(event)` for every event sent to it.
  """

  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.EventPipe.Event

  @doc """
  Subscribes to the background job implementation with the given AuthToken
  This allows for multiple sites to be run each with their own queue.
  """
  @callback subscribe(token :: %AuthToken{}) :: no_return()

  @doc """
  Sends an event to the Queue.
  """
  @callback enqueue(
              queue_name :: String.t(),
              worker :: module(),
              events :: list(Event.t()),
              opts :: any()
            ) :: no_return()

  @doc """
  Trigger when when the worker is finished with the response.
  """
  @callback fire_callback(Event.t()) :: {:ok, any()} | {:error, any()}
end
