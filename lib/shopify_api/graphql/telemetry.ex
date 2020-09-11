defmodule ShopifyAPI.GraphQL.Telemetry do
  @moduledoc """
  Helper module handle instrumentation with telemetry
  """
  alias HTTPoison.Error
  alias ShopifyAPI.GraphQL.Response

  def send(
        module_name,
        %{app_name: app, shop_name: shop} = _token,
        time,
        {:ok, %Response{response: response}} = _response
      ) do
    metadata = %{
      app: app,
      shop: shop,
      module: module_name,
      response: response
    }

    telemetry_execute(:success, time, metadata)
  end

  def send(
        module_name,
        %{app_name: app, shop_name: shop} = _token,
        time,
        response
      ) do
    reason =
      case response do
        {:error, %Response{response: reason}} -> reason
        {:error, %Error{reason: reason}} -> reason
      end

    metadata = %{
      app: app,
      shop: shop,
      module: module_name,
      reason: reason
    }

    telemetry_execute(:failure, time, metadata)
  end

  def send(_token, _method, _url, _time, _response), do: nil

  defp telemetry_execute(event_status, time, metadata) do
    :telemetry.execute(
      [:shopify_api, :graphql_request, event_status],
      %{request_time: time},
      metadata
    )
  end
end
