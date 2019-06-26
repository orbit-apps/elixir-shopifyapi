defmodule ShopifyAPI.REST.Location do
  @moduledoc """
  ShopifyAPI REST API Location resource
  """
  require Logger
  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST

  @doc """
  Return a list of locations.

  ## Example

      iex> ShopifyAPI.REST.Location.all(auth)
      {:ok, { "locations" => [] }}
  """
  def all(%AuthToken{} = auth), do: REST.get(auth, "locations.json")

  @doc """
  Return a single location.

  ## Example

    iex> ShopifyAPI.REST.Location.get(auth, integer)
    {:ok, %{ "location" => %{} }}
  """
  def get(%AuthToken{} = auth, location_id),
    do: REST.get(auth, "locations/#{location_id}.json")

  @doc """
  Return a count of locations.

  ## Example

    iex> ShopifyAPI.REST.Location.count(auth)
    {:ok, %{ "count" => integer }}
  """
  def count(%AuthToken{} = auth), do: REST.get(auth, "locations/count.json")

  @doc """
  Returns a list of inventory levels for a location.

  ## Example

    iex> ShopifyAPI.REST.Location.inventory_levels(auth, integer)
    {:ok, %{ "inventory_levels" => %{} }}
  """
  def inventory_levels(%AuthToken{} = auth, location_id),
    do: REST.get(auth, "locations/#{location_id}/inventory_levels.json")
end
