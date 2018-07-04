defmodule ShopifyAPI.EventPipe.InventoryLevelWorker do
  @moduledoc """
  Worker for processing Inventory Levels
  """
  require Logger
  import ShopifyAPI.EventPipe.Worker
  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST.InventoryLevel

  def perform(%{action: _, object: _, token: _} = event) do
    Logger.info(fn -> "#{__MODULE__} is processing an event: #{inspect(event)}" end)

    event
    |> Map.put(:response, call_shopify(event))
    |> fire_callback
  end

  defp call_shopify(%{action: "set", object: inventory_level} = event) do
    case fetch_token(event) do
      {:ok, token} ->
        InventoryLevel.set(struct(AuthToken, token), inventory_level)

      msg ->
        msg
    end
  end

  defp call_shopify(%{action: action}), do: {:error, "Unhandled action #{action}"}
end
