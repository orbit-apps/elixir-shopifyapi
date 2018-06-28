defmodule ShopifyAPI.EventPipe.ProductWorker do
  @moduledoc """
  Worker for processing Products
  """
  require Logger
  import ShopifyAPI.EventPipe.Worker
  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST.Product

  def perform(%{action: "create", object: _, token: _} = event) do
    Logger.info(fn -> "#{__MODULE__} is processing an event: #{inspect(event)}" end)
    stuff(event, fn t, %{object: product} -> Product.create(t, product) end)
  end

  def perform(%{action: "update", object: _, token: _} = event) do
    Logger.info(fn -> "#{__MODULE__} is processing an event: #{inspect(event)}" end)
    stuff(event, fn t, %{object: product} -> Product.update(t, product) end)
  end
end
