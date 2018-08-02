defmodule ShopifyAPI.EventPipe.LocationWorker do
  @moduledoc """
  Worker for processing Locations
  """
  require Logger
  import ShopifyAPI.EventPipe.Worker
  alias ShopifyAPI.REST.Location

  def perform(%{action: "all", object: _, token: _} = event),
    do: execute_action(event, fn token, _ -> Location.all(token) end)
end
