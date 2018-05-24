defmodule ShopifyApi.Rest.ApplicationCharge do
  @moduledoc """
  ShopifyApi REST API ApplicationCharge resource
  """

  alias ShopifyApi.AuthToken
  alias ShopifyApi.Rest.Request

  @doc """
  Create an application charge.

  ## Example

      iex> ShopifyApi.Rest.ApplicationCharge.create(auth, map)
      {:ok, { "application_charge" => %{} }}
  """
  def create(
        %AuthToken{} = auth,
        %{application_charge: %{}} = application_charge
      ) do
    Request.post(auth, "application_charges.json", application_charge)
  end

  @doc """
  Get a single application charge.

  ## Example

      iex> ShopifyApi.Rest.ApplicationCharge.get(auth, integer)
      {:ok, { "application_charge" => %{} }}
  """
  def get(%AuthToken{} = auth, application_charge_id) do
    Request.get(auth, "application_charges/#{application_charge_id}.json")
  end

  @doc """
  Get a list of all application charges.

  ## Example

      iex> ShopifyApi.Rest.ApplicationCharge.all(auth)
      {:ok, { "application_charges" => [] }}
  """
  def all(%AuthToken{} = auth) do
    Request.get(auth, "application_charges.json")
  end

  @doc """
  Active an application charge.

  ## Example

      iex> ShopifyApi.Rest.ApplicationCharge.activate(auth)
      {:ok, { "application_charge" => %{} }}
  """
  def activate(
        %AuthToken{} = auth,
        %{application_charge: %{id: application_charge_id}} = application_charge
      ) do
    Request.post(
      auth,
      "application_charges/#{application_charge_id}/activate.json",
      application_charge
    )
  end
end
