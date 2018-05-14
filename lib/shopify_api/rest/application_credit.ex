defmodule ShopifyApi.Rest.ApplicationCredit do
  @moduledoc """
  ShopifyApi REST API ApplicationCredit resource
  """

  alias ShopifyApi.AuthToken
  alias ShopifyApi.Rest.Request

  @doc """
  Create an application credit.

  ## Example

      iex> ShopifyApi.Rest.ApplicationCredit.create(auth, map)
      {:ok, { "application_credit" => %{} }}
  """
  def create(%AuthToken{} = auth, %{application_credit: {}} = application_credit) do
    Request.post(auth, "application_credits.json", application_credit)
  end

  @doc """
  Get a single application credit.

  ## Example

      iex> ShopifyApi.Rest.ApplicationCredit.get(auth, integer)
      {:ok, { "application_credit" => %{} }}
  """
  def get(%AuthToken{} = auth, application_credit_id) do
    Request.get(auth, "application_credits/#{application_credit_id}.json")
  end

  @doc """
  Get a list of all application credits.

  ## Example

      iex> ShopifyApi.Rest.ApplicationCredit.all(auth)
      {:ok, { "application_credits" => [] }}
  """
  def all(%AuthToken{} = auth) do
    Request.get(auth, "application_credits.json")
  end
end
