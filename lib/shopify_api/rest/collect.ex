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
      {:ok, %{} = collect}
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
      {:ok, [%{}, ...] = collects}
  """
  def all(%AuthToken{} = auth, params \\ [], options \\ []),
    do: REST.get(auth, "collects.json", params, options)

  @doc """
  Get a count of collects.

  ## Example

      iex> ShopifyAPI.REST.Collect.count(auth)
      {:ok, 123 = count}
  """
  def count(%AuthToken{} = auth, params \\ [], options \\ []),
    do: REST.get(auth, "collects/count.json", params, Keyword.merge([pagination: :none], options))

  @doc """
  Get a specific collect.

  ## Example

      iex> ShopifyAPI.REST.Collect.get(auth, id)
      {:ok, %{} = collect}
  """
  def get(%AuthToken{} = auth, collect_id, params \\ [], options \\ []),
    do:
      REST.get(
        auth,
        "collects/#{collect_id}.json",
        params,
        Keyword.merge([pagination: :none], options)
      )
end
