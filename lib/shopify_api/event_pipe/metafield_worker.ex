defmodule ShopifyAPI.EventPipe.MetafieldWorker do
  @moduledoc """
  Worker for processing Metafields

  Supports: get, create, update
  """
  require Logger
  import ShopifyAPI.EventPipe.Worker
  alias ShopifyAPI.REST.Metafield

  def perform(%{action: "create", object: _, token: _} = event) do
    event
    |> log
    |> execute_action(fn token, %{object: %{metafield: metafield, type: type, id: id}} ->
      Metafield.create(token, type, id, %{metafield: metafield})
    end)
  end

  def perform(%{action: "update", object: _, token: _} = event) do
    event
    |> log
    |> execute_action(fn token, %{object: %{metafield: metafield, type: type, id: id}} ->
      Metafield.update(token, type, id, %{metafield: metafield})
    end)
  end

  def perform(%{action: "get", object: _, token: _} = event) do
    event
    |> log
    |> execute_action(fn token, %{object: %{metafield: %{type: type, id: id}}} ->
      Metafield.all(token, type, id)
    end)
  end
end
