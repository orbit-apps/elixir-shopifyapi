defmodule ShopifyAPI.REST.UsageCharge do
  @moduledoc """
  ShopifyAPI REST API UsageCharge resource
  """

  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST

  @doc """
  Create a usage charge.

  ## Example

      iex> ShopifyAPI.REST.UsageCharge.create(auth, integer, map)
      {:ok, %{} = usage_charge}
  """
  def create(
        %AuthToken{} = auth,
        recurring_application_charge_id,
        usage_charge
      ) do
    REST.post(
      auth,
      "recurring_application_charges/#{recurring_application_charge_id}/usage_charges.json",
      usage_charge
    )
  end

  @doc """
  Retrieve a single charge.

  ## Example

      iex> ShopifyAPI.REST.UsageCharge.get(auth, integer)
      {:ok, %{} = usage_charge}
  """
  def get(
        %AuthToken{} = auth,
        recurring_application_charge_id,
        %{usage_charge: %{id: usage_charge_id}},
        params \\ [],
        options \\ []
      ) do
    REST.get(
      auth,
      "recurring_application_charges/#{recurring_application_charge_id}/usage_charges/#{usage_charge_id}.json",
      params,
      Keyword.merge([pagination: :none], options)
    )
  end

  @doc """
  Get of all the usage charges.

  ## Example

      iex> ShopifyAPI.REST.UsageCharge.all(auth, integer)
      {:ok, [] = usage_charges}
  """
  def all(%AuthToken{} = auth, recurring_application_charge_id, params \\ [], options \\ []) do
    REST.get(
      auth,
      "recurring_application_charge_id/#{recurring_application_charge_id}/usage_charges.json",
      params,
      Keyword.merge([pagination: :none], options)
    )
  end
end
