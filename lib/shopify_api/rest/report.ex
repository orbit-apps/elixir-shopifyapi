defmodule ShopifyAPI.REST.Report do
  @moduledoc """
  ShopifyAPI REST API Report resource
  """

  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST.Request

  @doc """
  Get a list of all reports.

  ## Example

      iex> ShopifyAPI.REST.Report.all(auth)
      {:ok, { "reports" => [] }}
  """
  def all(%AuthToken{} = auth) do
    Request.get(auth, "reports.json")
  end

  @doc """
  Return a single report.

  ## Example

      iex> ShopifyAPI.REST.Report.get(auth, integer)
      {:ok, { "report" => %{} }}
  """
  def get(%AuthToken{} = auth, report_id) do
    Request.get(auth, "reports/#{report_id}.json")
  end

  @doc """
  Create a new report.

  ## Example

      iex> ShopifyAPI.REST.Report.create(auth, map)
      {:ok, { "report" => %{} }}
  """
  def create(%AuthToken{} = auth, %{report: %{}} = report) do
    Request.post(auth, "reports.json", report)
  end

  @doc """
  Update a report.

  ## Example

      iex> ShopifyAPI.REST.Report.update(auth, map)
      {:ok, { "report" => %{} }}
  """
  def update(%AuthToken{} = auth, %{report: %{id: report_id}} = report) do
    Request.put(auth, "reports/#{report_id}.json", report)
  end

  @doc """
  Delete.

  ## Example

      iex> ShopifyAPI.REST.Report.Delete(auth)
      {:ok, 200 }}
  """
  def delete(%AuthToken{} = auth, report_id) do
    Request.delete(auth, "reports/#{report_id}.json")
  end
end
