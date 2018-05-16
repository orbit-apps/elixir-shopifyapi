defmodule ShopifyApi.Rest.CarrierService do
  @moduledoc """
  ShopifyApi REST API CarrierService resource
  """

  alias ShopifyApi.AuthToken
  alias ShopifyApi.Rest.Request

  @doc """
  Return a list of all carrier services.

  ## Example

      iex> ShopifyApi.Rest.CarrierService.all(auth)
      {:ok, { "carrier_services" => [] }}
  """
  def all(%AuthToken{} = auth) do
    Request.get(auth, "carrier_services.json")
  end

  @doc """
  Get a single carrier service.

  ## Example

      iex> ShopifyApi.Rest.CarrierService.get(auth, string)
      {:ok, { "carrier_service" => %{} }}
  """
  def get(%AuthToken{} = auth, carrier_service_id) do
    Request.get(auth, "carrier_services/#{carrier_service_id}.json")
  end

  @doc """
  Create a carrier service.

  ## Example

      iex> ShopifyApi.Rest.CarrierService.create(auth, map)
      {:ok, { "carrier_service" => %{} }}
  """
  def create(%AuthToken{} = auth, %{carrier_service: %{}} = carrier_service) do
    Request.post(auth, "carrier_services.json", carrier_service)
  end

  @doc """
  Update a carrier service.

  ## Example

      iex> ShopifyApi.Rest.CarrierService.update(auth)
      {:ok, { "carrier_service" => %{} }}
  """
  def update(%AuthToken{} = auth, %{carrier_service: %{id: carrier_service_id}} = carrier_service) do
    Request.put(auth, "carrier_services/#{carrier_service_id}.json", carrier_service)
  end

  @doc """
  Delete a carrier service.

  ## Example

      iex> ShopifyApi.Rest.CarrierService.delete(auth, string)
      {:ok, 200 }
  """
  def delete(%AuthToken{} = auth, carrier_service_id) do
    Request.delete(auth, "carrier_services/#{carrier_service_id}.json")
  end
end
