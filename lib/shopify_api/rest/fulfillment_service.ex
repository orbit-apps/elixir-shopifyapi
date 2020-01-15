defmodule ShopifyAPI.REST.FulfillmentService do
  @moduledoc """
  ShopifyAPI REST API FulfillmentService resource
  """

  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST

  @doc """
  Return a list of all the fulfillment services.

  ## Example

      iex> ShopifyAPI.REST.FulfillmentService.all(auth)
      {:ok, { "fulfillment_services" => [] }}
  """
  def all(%AuthToken{} = auth, params \\ []),
    do: REST.get(auth, "fulfillment_services.json", params)

  @doc """
  Get a single fulfillment service.

  ## Example

      iex> ShopifyAPI.REST.FulfillmentService.get(auth, string)
      {:ok, { "fulfillment_service" => %{} }}
  """
  def get(%AuthToken{} = auth, fulfillment_service_id, params \\ []),
    do: REST.get(auth, "fulfillment_services/#{fulfillment_service_id}.json", params)

  @doc """
  Create a new fulfillment service.

  ## Example

      iex> ShopifyAPI.REST.FulfillmentService.create(auth)
      {:ok, { "fulfillment_service" => %{} }}
  """
  def create(%AuthToken{} = auth, %{fulfillment_service: %{}} = fulfillment_service),
    do: REST.post(auth, "fulfillment_services.json", fulfillment_service)

  @doc """
  Update an existing fulfillment service.

  ## Example

      iex> ShopifyAPI.REST.FulfillmentService.update(auth)
      {:ok, { "fulfillment_service" => %{} }}
  """
  def update(
        %AuthToken{} = auth,
        %{fulfillment_service: %{id: fulfillment_service_id}} = fulfillment_service
      ) do
    REST.put(auth, "fulfillment_services/#{fulfillment_service_id}.json", fulfillment_service)
  end

  @doc """
  Delete a fulfillment service.

  ## Example

      iex> ShopifyAPI.REST.FulfillmentService.delete(auth, string)
      {:ok, 200 }
  """
  def delete(%AuthToken{} = auth, fulfillment_service_id),
    do: REST.delete(auth, "fulfillment_services/#{fulfillment_service_id}.json")
end
