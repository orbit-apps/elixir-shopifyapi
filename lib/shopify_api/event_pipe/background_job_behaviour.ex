defmodule ShopifyAPI.EventPipe.BackgroundJobBehaviour do
  @moduledoc """
  Defines what an implementation for a background job handler can be.

  By default Exq will be used and needs to be configured.

  You can set the implmentation with `Applicaiton.set_env(:shopify_api, :background_job_implementation, MyImplementation)`

  The implementation is respnsible for calling `worker.perform(event)` for every event sent to it.
  """

  @callback enqueue(
              queue_name :: String.t(),
              worker :: module(),
              events :: list(ShopifyAPI.EventPipe.Event.t()),
              opts :: any()
            ) :: no_return()
end
