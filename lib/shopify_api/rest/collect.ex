defmodule ShopifyApi.Rest.Collect do
  @moduledoc """
  ShopifyApi REST API Collect resource
  """

  alias ShopifyApi.AuthToken
  alias ShopifyApi.Rest.Request

  @doc """
  Add a product to custom collection.

  ## Example

      iex> ShopifyApi.Rest.Request.add(auth)
      {:ok, { "collect" => %{} }}
  """
  def add(%AuthToken{} = auth, %{collect: %{}} = collect) do
    Request.post(auth, "collects.json", collect)
  end

  @doc """
  Remove a product from a custom collection.

  ## Example

      iex> ShopifyApi.Rest.Delete(auth, string)
      {:ok, 200 }
  """
  def delete(%AuthToken{} = auth, collect_id) do
    Request.delete(auth, "collects/#{collect_id}.json")
  end

  @doc """
  Get list of all collects.

  ## Example

      iex> ShopifyApi.Rest.Get(auth)
      {:ok, { "collects" => [] }}
  """
  def all(%AuthToken{} = auth) do
    Request.get(auth, "collects.json")
  end

  @doc """
  Get a count of collects.

  ## Example

      iex> ShopifyApi.Rest.Count(auth)
      {:ok, { "count": integer }}
  """
  def count(%AuthToken{} = auth) do
    Request.get(auth, "collects/count.json")
  end

  @doc """
  Get a specific collect.

  ## Example

      iex> ShopifyApi.Rest.Get(auth, string)
      {:ok, { "collect" => %{} }}
  """
  def get(%AuthToken{} = auth, collect_id) do
    Request.get(auth, "collects/#{collect_id}.json")
  end
end
