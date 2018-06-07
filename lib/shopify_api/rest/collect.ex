defmodule ShopifyAPI.REST.Collect do
  @moduledoc """
  ShopifyAPI REST API Collect resource
  """

  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST.Request

  @doc """
  Add a product to custom collection.

  ## Example

      iex> ShopifyAPI.REST.Request.add(auth)
      {:ok, { "collect" => %{} }}
  """
  def add(%AuthToken{} = auth, %{collect: %{}} = collect) do
    Request.post(auth, "collects.json", collect)
  end

  @doc """
  Remove a product from a custom collection.

  ## Example

      iex> ShopifyAPI.REST.Delete(auth, string)
      {:ok, 200 }
  """
  def delete(%AuthToken{} = auth, collect_id) do
    Request.delete(auth, "collects/#{collect_id}.json")
  end

  @doc """
  Get list of all collects.

  ## Example

      iex> ShopifyAPI.REST.Get(auth)
      {:ok, { "collects" => [] }}
  """
  def all(%AuthToken{} = auth) do
    Request.get(auth, "collects.json")
  end

  @doc """
  Get a count of collects.

  ## Example

      iex> ShopifyAPI.REST.Count(auth)
      {:ok, { "count": integer }}
  """
  def count(%AuthToken{} = auth) do
    Request.get(auth, "collects/count.json")
  end

  @doc """
  Get a specific collect.

  ## Example

      iex> ShopifyAPI.REST.Get(auth, string)
      {:ok, { "collect" => %{} }}
  """
  def get(%AuthToken{} = auth, collect_id) do
    Request.get(auth, "collects/#{collect_id}.json")
  end
end
