defmodule ShopifyApi.Rest.Fulfillment do
  @moduledoc """
  ShopifyApi REST API Fulfillment resource
  """

  alias ShopifyApi.AuthToken
  alias ShopifyApi.Rest.Request

  @doc """
  Return a list of all fulfillments.

  ## Example

      iex> ShopifyApi.Rest.Fulfillment.all(auth, string)
      {:ok, { "fulfillments" => [] }}
  """
  def all(%AuthToken{} = auth, order_id) do
    Request.get(auth, "orders/#{order_id}/fulfillments.json")
  end

  @doc """
  Return a count of all fulfillments.

  ## Example

      iex> ShopifyApi.Rest.Fulfillment.count(auth, string)
      {:ok, { "count" => integer }}
  """
  def count(%AuthToken{} = auth, order_id) do
    Request.get(auth, "orders/#{order_id}/fulfillments/count.json")
  end

  @doc """
  Get a single fulfillment.

  ## Example

      iex> ShopifyApi.Rest.Fulfillment.get(auth, string, string)
      {:ok, { "fulfillment" => %{} }}
  """
  def get(%AuthToken{} = auth, order_id, fulfillment_id) do
    Request.get(auth, "orders/#{order_id}/fulfillments/#{fulfillment_id}.json")
  end

  @doc """
  Create a new fulfillment.

  ## Example

      iex> ShopifyApi.Rest.Fulfillment.create(auth, string, map)
      {:ok, { "fulfillment" => %{} }}
  """
  def create(%AuthToken{} = auth, order_id, %{fulfillment: %{}} = fulfillment) do
    Request.post(auth, "orders/#{order_id}/fulfillment.json", fulfillment)
  end

  @doc """
  Update an existing fulfillment.

  ## Example

      iex> ShopifyApi.Rest.Fulfillment.update(auth, string, map)
      {:ok, { "fulfillment" => %{} }}
  """
  def update(
        %AuthToken{} = auth,
        order_id,
        %{fulfillment: %{id: fulfillment_id}} = fulfillment
      ) do
    Request.put(auth, "orders/#{order_id}/fulfillments/#{fulfillment_id}.json", fulfillment)
  end

  @doc """
  Complete a fulfillment.

  ## Example

      iex> ShopifyApi.Rest.Fulfillment.complete(auth, string, map)
      {:ok, { "fulfillment" => %{} }}
  """
  def complete(%AuthToken{} = auth, order_id, %{fulfillment: %{id: fulfillment_id}} = fulfillment) do
    Request.post(
      auth,
      "orders/#{order_id}/fulfillments/#{fulfillment_id}/complete.json",
      fulfillment
    )
  end

  @doc """
  Open a fulfillment.

  ## Example

      iex> ShopifyApi.Rest.Fulfillment.open(auth, string)
      {:ok, { "fulfillment" => %{} }}
  """
  def open(%AuthToken{} = auth, order_id, %{fulfillment: %{id: fulfillment_id}} = fulfillment) do
    Request.post(
      auth,
      "orders/#{order_id}/fulfillments/#{fulfillment_id}/open.json",
      fulfillment
    )
  end

  @doc """
  Cancel a fulfillment.

  ## Example

      iex> ShopifyApi.Rest.Fulfillment.cancel(auth, string)
      {:ok, { "fulfillment" => %{} }}
  """
  def cancel(%AuthToken{} = auth, order_id, %{fulfillment: %{id: fulfillment_id}} = fulfillment) do
    Request.post(
      auth,
      "orders/#{order_id}/fulfillments/#{fulfillment_id}/cancel.json",
      fulfillment
    )
  end
end
