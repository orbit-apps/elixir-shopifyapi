defmodule ShopifyAPI.EventPipe.LocationWorker do
  @moduledoc """
  Worker for processing Locations
  """
  require Logger
  import ShopifyAPI.EventPipe.Worker
  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST.Location

  def perform(%{action: _, object: _, token: _} = event) do
    Logger.info(fn -> "#{__MODULE__} is processing an event: #{inspect(event)}" end)

    event
    |> Map.put(:response, call_shopify(event))
    |> fire_callback
  end

  defp call_shopify(%{action: "all", object: _} = event) do
    case fetch_token(event) do
      {:ok, token} ->
        Location.all(struct(AuthToken, token))

      msg ->
        msg
    end
  end

  defp call_shopify(%{action: action}), do: {:error, "Unhandled action #{action}"}
end
