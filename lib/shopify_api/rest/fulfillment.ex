defmodule ShopifyAPI.REST.Fulfillment do
  @moduledoc """
  ShopifyAPI REST API Fulfillment resource
  """

  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST

  @doc """
  Return a list of all fulfillments.

  ## Example

      iex> ShopifyAPI.REST.Fulfillment.all(auth, string)
      {:ok, [%{}, ...] = fulfillments}
  """
  def all(%AuthToken{} = auth, order_id, params \\ [], options \\ []),
    do: REST.get(auth, "orders/#{order_id}/fulfillments.json", params, options)

  @doc """
  Return a count of all fulfillments.

  ## Example

      iex> ShopifyAPI.REST.Fulfillment.count(auth, string)
      {:ok, integer}
  """
  def count(%AuthToken{} = auth, order_id, params \\ [], options \\ []),
    do:
      REST.get(
        auth,
        "orders/#{order_id}/fulfillments/count.json",
        params,
        Keyword.merge([pagination: :none], options)
      )

  @doc """
  Get a single fulfillment.

  ## Example

      iex> ShopifyAPI.REST.Fulfillment.get(auth, string, string)
      {:ok, %{} = fulfillment}
  """
  def get(%AuthToken{} = auth, order_id, fulfillment_id, params \\ [], options \\ []),
    do:
      REST.get(
        auth,
        "orders/#{order_id}/fulfillments/#{fulfillment_id}.json",
        params,
        Keyword.merge([pagination: :none], options)
      )

  @doc """
  Create a new fulfillment.

  ## Example

      iex> ShopifyAPI.REST.Fulfillment.create(auth, string, map)
      {:ok, %{} = fulfillment}
  """
  def create(%AuthToken{} = auth, order_id, %{fulfillment: %{}} = fulfillment, options \\ []) do
    REST.post(auth, "orders/#{order_id}/fulfillments.json", fulfillment, options)
  end

  @doc """
  Update an existing fulfillment.

  ## Example

      iex> ShopifyAPI.REST.Fulfillment.update(auth, string, map)
      {:ok, %{} = fulfillment}
  """
  def update(
        %AuthToken{} = auth,
        order_id,
        %{fulfillment: %{id: fulfillment_id}} = fulfillment
      ),
      do: REST.put(auth, "orders/#{order_id}/fulfillments/#{fulfillment_id}.json", fulfillment)

  @doc """
  Complete a fulfillment.

  ## Example

      iex> ShopifyAPI.REST.Fulfillment.complete(auth, string, map)
      {:ok, %{} = fulfillment}
  """
  def complete(%AuthToken{} = auth, order_id, %{fulfillment: %{id: fulfillment_id}} = fulfillment) do
    REST.post(
      auth,
      "orders/#{order_id}/fulfillments/#{fulfillment_id}/complete.json",
      fulfillment
    )
  end

  @doc """
  Open a fulfillment.

  ## Example

      iex> ShopifyAPI.REST.Fulfillment.open(auth, string)
      {:ok, %{} = fulfillment}
  """
  def open(%AuthToken{} = auth, order_id, %{fulfillment: %{id: fulfillment_id}} = fulfillment) do
    REST.post(
      auth,
      "orders/#{order_id}/fulfillments/#{fulfillment_id}/open.json",
      fulfillment
    )
  end

  @doc """
  Cancel a fulfillment.

  ## Example

      iex> ShopifyAPI.REST.Fulfillment.cancel(auth, string)
      {:ok, %{} = fulfillment}
  """
  def cancel(%AuthToken{} = auth, order_id, %{fulfillment: %{id: fulfillment_id}} = fulfillment) do
    REST.post(
      auth,
      "orders/#{order_id}/fulfillments/#{fulfillment_id}/cancel.json",
      fulfillment
    )
  end
end
