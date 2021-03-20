defmodule ShopifyAPI.REST.RecurringApplicationCharge do
  @moduledoc """
  ShopifyAPI REST API Recurring Application Charge resource
  """

  require Logger
  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST

  @doc """
  Create a recurring application charge.

  ## Example

      iex> ShopifyAPI.REST.RecurringApplicationCharge.create(auth, %{recurring_application_charge: map()})
      {:ok, %{} = recurring_application_charge}

        or

      iex> ShopifyAPI.REST.RecurringApplicationCharge.create(auth, map)
      {:ok, %{} = recurring_application_charge}

  """
  def create(
        %AuthToken{} = auth,
        %{recurring_application_charge: %{}} = recurring_application_charge
      ) do
    REST.post(auth, "recurring_application_charges.json", recurring_application_charge)
  end
  
  def create(
        %AuthToken{} = auth,
        %{} = recurring_application_charge
      ) do
    REST.post(auth, "recurring_application_charges.json", %{
      recurring_application_charge: recurring_application_charge
    })
  end

  @doc """
  Get a single charge.

  ## Example

      iex> ShopifyAPI.REST.RecurringApplicationCharge.get(auth, integer)
      {:ok, %{} = recurring_application_charge}
  """
  def get(%AuthToken{} = auth, recurring_application_charge_id, params \\ [], options \\ []) do
    REST.get(
      auth,
      "recurring_application_charges/#{recurring_application_charge_id}.json",
      params,
      Keyword.merge([pagination: :none], options)
    )
  end

  @doc """
  Get a list of all recurring application charges.

  ## Example

      iex> ShopifyAPI.REST.RecurringApplicationCharge.all(auth)
      {:ok, [] = recurring_application_charges}
  """
  def all(%AuthToken{} = auth, params \\ [], options \\ []),
    do:
      REST.get(
        auth,
        "recurring_application_charges.json",
        params,
        Keyword.merge([pagination: :none], options)
      )

  @doc """
  Activates a recurring application charge.

  ## Example

      iex> ShopifyAPI.REST.RecurringApplicationCharge.activate(auth, integer)
      {:ok, %{} = recurring_application_charge}
  """
  def activate(%AuthToken{} = auth, recurring_application_charge_id) do
    REST.post(
      auth,
      "recurring_application_charges/#{recurring_application_charge_id}/activate.json"
    )
  end

  @doc """
  Cancels a recurring application charge.

  ## Example

      iex> ShopifyAPI.REST.RecurringApplicationCharge.cancel(auth, integer)
      {:ok, 200 }
  """
  def cancel(%AuthToken{} = auth, recurring_application_charge_id),
    do:
      REST.delete(
        auth,
        "recurring_application_charges/#{recurring_application_charge_id}.json"
      )

  @doc """
  Updates a capped amount of recurring application charge.

  ## Example

      iex> ShopifyAPI.REST.RecurringApplicationCharge.update()
      {:error, "Not implemented" }
  """
  def update do
    Logger.warn("#{__MODULE__} error, resource not implemented.")
    {:error, "Not implemented"}
  end
end
