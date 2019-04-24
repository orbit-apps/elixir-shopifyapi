defmodule ShopifyAPI.EventPipe.InventoryLevelWorker do
  @moduledoc """
  Worker for processing Inventory Levels
  """
  require Logger
  import ShopifyAPI.EventPipe.Worker
  alias ShopifyAPI.EventPipe.Event
  alias ShopifyAPI.REST.InventoryLevel

  def perform(%Event{action: "set", object: _, token: _} = event) do
    execute_action(event, fn token, %{object: level} -> InventoryLevel.set(token, level) end)
  end
end
