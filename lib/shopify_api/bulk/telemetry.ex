defmodule ShopifyAPI.Bulk.Telemetry do
  @moduledoc """
  Helper module handle instrumentation with telemetry
  """

  def send(module_name, token, data, bulk_id \\ nil)

  def send(
        module_name,
        %{app_name: app, shop_name: shop} = _token,
        {:error, type, reason},
        bulk_id
      ) do
    metadata = %{
      app: app,
      shop: shop,
      module: module_name,
      bulk_id: bulk_id,
      type: type,
      reason: reason
    }

    telemetry_execute(:failure, metadata)
  end

  def send(
        module_name,
        %{app_name: app, shop_name: shop} = _token,
        {:success, type},
        _bulk_id
      ) do
    metadata = %{
      app: app,
      shop: shop,
      module: module_name,
      type: type
    }

    telemetry_execute(:success, metadata)
  end

  defp telemetry_execute(event_status, metadata) do
    :telemetry.execute(
      [:shopify_api, :bulk_operation, event_status],
      %{count: 1},
      metadata
    )
  end
end
