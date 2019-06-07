defmodule ShopifyAPI.REST.ApplicationCharge do
  @moduledoc """
  ShopifyAPI REST API ApplicationCharge resource
  """

  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST

  @doc """
  Create an application charge.

  ## Example

      iex> ShopifyAPI.REST.ApplicationCharge.create(auth, map)
      {:ok, { "application_charge" => %{} }}
  """
  def create(
        %AuthToken{} = auth,
        %{application_charge: %{}} = application_charge
      ),
      do: REST.post(auth, "application_charges.json", application_charge)

  @doc """
  Get a single application charge.

  ## Example

      iex> ShopifyAPI.REST.ApplicationCharge.get(auth, integer)
      {:ok, { "application_charge" => %{} }}
  """
  def get(%AuthToken{} = auth, application_charge_id),
    do: REST.get(auth, "application_charges/#{application_charge_id}.json")

  @doc """
  Get a list of all application charges.

  ## Example

      iex> ShopifyAPI.REST.ApplicationCharge.all(auth)
      {:ok, { "application_charges" => [] }}
  """
  def all(%AuthToken{} = auth), do: REST.get(auth, "application_charges.json")

  @doc """
  Active an application charge.

  ## Example

      iex> ShopifyAPI.REST.ApplicationCharge.activate(auth)
      {:ok, { "application_charge" => %{} }}
  """
  def activate(
        %AuthToken{} = auth,
        %{application_charge: %{id: application_charge_id}} = application_charge
      ) do
    REST.post(
      auth,
      "application_charges/#{application_charge_id}/activate.json",
      application_charge
    )
  end
end
