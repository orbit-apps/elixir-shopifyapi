defmodule ShopifyAPI.EventPipe.ProductWorker do
  @moduledoc """
  Worker for processing Products
  """
  require Logger
  import ShopifyAPI.EventPipe.Worker
  alias ShopifyAPI.REST.Product

  def perform(%{action: "create", object: _, token: _} = event) do
    event
    |> log
    |> execute_action(fn token, %{object: product} -> Product.create(token, product) end)
  end

  def perform(%{action: "update", object: _, token: _} = event) do
    event
    |> log
    |> execute_action(fn token, %{object: product} -> Product.update(token, product) end)
  end
end
