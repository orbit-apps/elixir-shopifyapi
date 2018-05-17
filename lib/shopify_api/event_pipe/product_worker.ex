defmodule ShopifyApi.EventPipe.ProductWorker do
  @moduledoc """
  Exq worker for procecessing Products
  """
  require Logger
  import ShopifyApi.EventPipe.Worker
  alias ShopifyApi.Rest.Product

  def perform(%{"action" => _, "object" => _, "token" => _} = event) do
    Logger.info("#{__MODULE__} is processing an event")
    Logger.info(inspect(event))

    event
    |> Map.put(:response, call_shopify(event))
    |> fire_callback
  end

  defp call_shopify(%{"action" => "create", "object" => product} = event),
    do: Product.create(fetch_token(event), product)

  defp call_shopify(%{"action" => "update", "object" => product} = event),
    do: Product.update(fetch_token(event), product)

  defp call_shopify(%{"action" => action}), do: {:error, "Unhandled action #{action}"}
end
