defmodule ShopifyAPI.EventPipe.Worker do
  @moduledoc """
  Collection of helpful functions for Shopify workers.
  """
  require Logger
  alias ShopifyAPI.AuthToken

  def perform(event), do: Logger.warn(fn -> "Failed to process event: #{inspect(event)}" end)

  def execute_action(event, work) do
    case fetch_token(event) do
      {:ok, token} ->
        event
        |> Map.put(:response, work.(struct(AuthToken, token), event))
        |> fire_callback

      msg ->
        msg
    end
  end

  def log(event) do
    Logger.info(fn -> "#{__MODULE__} is processing an event: #{inspect(event)}" end)
    event
  end

  defp fire_callback(%{callback: callback} = event) when is_binary(callback) do
    Task.start(fn ->
      Logger.info(fn -> "Firing call back to #{callback} with #{inspect(event)}" end)
      {func, _} = Code.eval_string(callback)
      func.(event)
    end)
  end

  defp fire_callback(%{callback: callback}) when is_nil(callback),
    do: {:ok, "no callback to call"}

  defp fire_callback(_event), do: {:ok, ""}

  defp fetch_token(event) do
    Map.fetch(event, :token)
  end
end
