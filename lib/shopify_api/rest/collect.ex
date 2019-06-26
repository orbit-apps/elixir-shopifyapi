defmodule ShopifyAPI.REST.Collect do
  @moduledoc """
  ShopifyAPI REST API Collect resource
  """

  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST

  @doc """
  Add a product to custom collection.

  ## Example

      iex> ShopifyAPI.REST.Collect.add(auth, %{collect: collect})
      {:ok, %{ "collect" => %{} }}
  """
  def add(%AuthToken{} = auth, %{collect: %{}} = collect),
    do: REST.post(auth, "collects.json", collect)

  @doc """
  Remove a product from a custom collection.

  ## Example

      iex> ShopifyAPI.REST.Collect.delete(auth, collect_id)
      {:ok, 200}
  """
  def delete(%AuthToken{} = auth, collect_id),
    do: REST.delete(auth, "collects/#{collect_id}.json")

  @doc """
  Get list of all collects.

  ## Example

      iex> ShopifyAPI.REST.Collect.all(auth)
      {:ok, %{ "collects" => [] }}
  """
  def all(%AuthToken{} = auth), do: REST.get(auth, "collects.json")

  @doc """
  Get a count of collects.

  ## Example

      iex> ShopifyAPI.REST.Collect.count(auth)
      {:ok, %{ "count" => 123 }}
  """
  def count(%AuthToken{} = auth), do: REST.get(auth, "collects/count.json")

  @doc """
  Get a specific collect.

  ## Example

      iex> ShopifyAPI.REST.Collect.get(auth, id)
      {:ok, %{ "collect" => %{} }}
  """
  def get(%AuthToken{} = auth, collect_id), do: REST.get(auth, "collects/#{collect_id}.json")
end
