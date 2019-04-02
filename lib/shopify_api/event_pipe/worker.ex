defmodule ShopifyAPI.EventPipe.Worker do
  @moduledoc """
  Collection of helpful functions for Shopify workers.
  """
  require Logger
  alias ShopifyAPI.AuthToken

  def perform(event), do: Logger.warn(fn -> "Failed to process event: #{inspect(event)}" end)

  def execute_action(event, work) when is_function(work) do
    Logger.info(fn -> "#{__MODULE__} is processing an event: #{inspect(event)}" end)

    with {:ok, token} <- fetch_token(event),
         auth_token <- ensure_auth_token(token),
         response <- work.(auth_token, event),
         event_with_response <- Map.put(event, :response, response) do
      fire_callback(event_with_response)
    else
      msg -> msg
    end
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

  def ensure_auth_token(%AuthToken{} = token), do: token
  def ensure_auth_token(token), do: struct(AuthToken, token)
end
