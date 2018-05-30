defmodule ShopifyApi.EventPipe.Worker do
  @moduledoc """
  Collection of helpful functions for Shopify workers.
  """
  require Logger

  def perform(event), do: Logger.warn("Failed to process event: #{inspect(event)}")

  def fire_callback(%{callback: callback} = event) when is_binary(callback) do
    Task.async(fn ->
      {func, _} = Code.eval_string(callback)
      func.(event)
    end)
  end

  def fire_callback(%{callback: callback}) when is_nil(callback) do
    {:ok, "no callback to call"}
  end

  def fire_callback(event) do
    {:ok, ""}
  end

  def fetch_token(event) do
    with {:ok, str_token} <- Map.fetch(event, "token"),
         token <- str_map_to_atom(str_token),
         struct_token <- struct(ShopifyApi.AuthToken, token) do
      struct_token
    else
      _ -> {:error, "failed to find token"}
    end
  end

  def str_map_to_atom(map) do
    for {key, val} <- map, into: %{}, do: {String.to_existing_atom(key), val}
  end
end
