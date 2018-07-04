defmodule ShopifyAPI.EventPipe.LocationWorker do
  @moduledoc """
  Worker for processing Locations
  """
  require Logger
  import ShopifyAPI.EventPipe.Worker
  alias ShopifyAPI.REST.Location

  def perform(%{action: "all", object: _, token: _} = event) do
    event
    |> log
    |> execute_action(fn token, _ -> Location.all(token) end)
  end
end
