defmodule ShopifyApi.Collect do
  @moduledoc """
    ShopifyApi REST Collect resouce
  """

  alias ShopifyApi.AuthToken
  alias ShopifyApi.Rest.Request

  @doc """
    Add a product to custom collection.

    iex> ShopifyApi.Rest.Request.add(token)
  """
  def add(%AuthToken{} = auth, %{collect: %{}} = collect) do
    Request.post(auth, "admin/collects.json", collect)
  end

  @doc """
    Remove a product from a collection.

    iex> ShopifyApi.Rest.Delete(token, string)
  """
  def delete(%AuthToken{} = auth, collect_id) do
    Request.delete(auth, "admin/collects/#{collect_id}.json")
  end

  @doc """
    Get list of all collects.

    iex> ShopifyApi.Rest.Get(token)
  """
  def all(%AuthToken{} = auth) do
    Request.get(auth, "admin/collects.json")
  end

  @doc """
    Get a count of collects.

    iex> ShopifyApi.Rest.Count(token)
  """
  def count(%AuthToken{} = auth) do
    Request.get(auth, "admin/collects/count.json")
  end

  @doc """
    Get a specific collect.

    iex> ShopifyApi.Rest.Get(token, string)
  """
  def get(%AuthToken{} = auth, collect_id) do
    Request.get(auth, "admin/collects/#{collect_id}.json")
  end
end
