defmodule ShopifyAPI.EventPipe.VariantWorker do
  @moduledoc """
  Worker for processing Variants
  """
  require Logger
  import ShopifyAPI.EventPipe.Worker
  alias ShopifyAPI.REST.Variant

  def perform(%{action: "create", object: _, token: _} = event) do
    event
    |> log
    |> execute_action(fn token, %{object: %{variant: %{product_id: product_id}} = variant} ->
      Variant.create(token, product_id, variant)
    end)
  end

  def perform(%{action: "update", object: _, token: _} = event) do
    event
    |> log
    |> execute_action(fn token, %{object: variant} -> Variant.update(token, variant) end)
  end
end
