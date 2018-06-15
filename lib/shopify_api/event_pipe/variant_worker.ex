defmodule ShopifyAPI.EventPipe.VariantWorker do
  @moduledoc """
  Worker for processing Variants
  """
  require Logger
  import ShopifyAPI.EventPipe.Worker
  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST.Variant

  def perform(%{action: _, object: _, token: _} = event) do
    Logger.info(fn -> "#{__MODULE__} is processing an event: #{inspect(event)}" end)

    event
    |> Map.put(:response, call_shopify(event))
    |> fire_callback
  end

  defp call_shopify(%{action: "create", object: %{product_id: product_id} = variant} = event) do
    case fetch_token(event) do
      {:ok, token} ->
        Variant.create(struct(AuthToken, token), product_id, variant)

      msg ->
        msg
    end
  end

  defp call_shopify(%{action: "update", object: variant} = event) do
    case fetch_token(event) do
      {:ok, token} ->
        Variant.update(struct(AuthToken, token), variant)

      msg ->
        msg
    end
  end

  defp call_shopify(%{action: action}), do: {:error, "Unhandled action #{action}"}
end
