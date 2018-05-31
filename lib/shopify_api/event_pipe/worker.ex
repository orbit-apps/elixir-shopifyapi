defmodule ShopifyApi.EventPipe.Worker do
  @moduledoc """
  Collection of helpful functions for Shopify workers.
  """
  require Logger

  def perform(event), do: Logger.warn("Failed to process event: #{inspect(event)}")

  def fire_callback(%{callback: callback} = event) when is_binary(callback) do
    Task.start(fn ->
      {func, _} = Code.eval_string(callback)
      func.(event)
    end)
  end

  def fire_callback(%{callback: callback}) when is_nil(callback), do: {:ok, "no callback to call"}
  def fire_callback(event), do: {:ok, ""}

  def fetch_token(event) do
    Map.fetch(event, :token)
  end
end
