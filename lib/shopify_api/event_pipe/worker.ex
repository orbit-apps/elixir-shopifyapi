defmodule ShopifyAPI.EventPipe.Worker do
  @moduledoc """
  Collection of helpful functions for Shopify workers.
  """
  require Logger

  import ShopifyAPI.EventPipe.Logging

  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.EventPipe.{Event, EventQueue}

  @spec perform(Event.t()) :: :ok | {:error, any()}
  def perform(event), do: Logger.warn(fn -> "Failed to process event: #{inspect(event)}" end)

  @spec execute_action(Event.t(), Event.callback()) :: any()
  def execute_action(event, work) when is_function(work) do
    log_metadata(event)

    with {:ok, token} <- fetch_token(event),
         auth_token <- ensure_auth_token(token),
         response <- work.(auth_token, event),
         event_with_response <- Map.put(event, :response, response) do
      EventQueue.fire_callback(event_with_response)
    else
      msg -> msg
    end
  end

  defp fetch_token(event) do
    Map.fetch(event, :token)
  end

  def ensure_auth_token(%AuthToken{} = token), do: token
  def ensure_auth_token(token), do: struct(AuthToken, token)
end
