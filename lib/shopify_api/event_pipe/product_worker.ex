defmodule ShopifyAPI.EventPipe.ProductWorker do
  @moduledoc """
  Worker for processing Products
  """
  require Logger
  import ShopifyAPI.EventPipe.Worker
  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST.Product

  def perform(%{action: _, object: _, token: _} = event) do
    Logger.info(fn -> "#{__MODULE__} is processing an event: #{inspect(event)}" end)

    event
    |> Map.put(:response, call_shopify(event))
    |> fire_callback
  end

  defp call_shopify(%{action: "create", object: product} = event) do
    case fetch_token(event) do
      {:ok, token} ->
        Product.create(struct(AuthToken, token), product)

      msg ->
        msg
    end
  end

  defp call_shopify(%{action: "update", object: product} = event) do
    case fetch_token(event) do
      {:ok, token} ->
        Product.update(struct(AuthToken, token), product)

      msg ->
        msg
    end
  end

  defp call_shopify(%{action: action}), do: {:error, "Unhandled action #{action}"}
end
