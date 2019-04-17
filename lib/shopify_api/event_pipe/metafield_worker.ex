defmodule ShopifyAPI.EventPipe.MetafieldWorker do
  @moduledoc """
  Worker for processing Metafields

  Supports: get, create, update
  """
  require Logger
  import ShopifyAPI.EventPipe.Worker
  alias ShopifyAPI.EventPipe.Event
  alias ShopifyAPI.REST.Metafield

  def perform(%Event{action: "create", object: _, token: _} = event) do
    execute_action(event, fn token, %{object: %{metafield: metafield, type: type, id: id}} ->
      Metafield.create(token, type, id, %{metafield: metafield})
    end)
  end

  def perform(%Event{action: "update", object: _, token: _} = event) do
    execute_action(event, fn token, %{object: %{metafield: metafield, type: type, id: id}} ->
      Metafield.update(token, type, id, %{metafield: metafield})
    end)
  end

  def perform(%Event{action: "get", object: _, token: _} = event) do
    execute_action(event, fn token, %{object: %{metafield: %{type: type, id: id}}} ->
      Metafield.all(token, type, id)
    end)
  end
end
