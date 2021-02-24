defmodule ShopifyAPI.REST.Location do
  @moduledoc """
  ShopifyAPI REST API Location resource
  """

  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST

  require Logger

  @doc """
  Return a list of locations.

  ## Example

      iex> ShopifyAPI.REST.Location.all(auth)
      {:ok, [] = locations}
  """
  def all(%AuthToken{} = auth, params \\ [], options \\ []),
    do: REST.get(auth, "locations.json", params, Keyword.merge([pagination: :none], options))

  @doc """
  Return a single location.

  ## Example

    iex> ShopifyAPI.REST.Location.get(auth, integer)
    {:ok, %{} = location}
  """
  def get(%AuthToken{} = auth, location_id, params \\ [], options \\ []),
    do:
      REST.get(
        auth,
        "locations/#{location_id}.json",
        params,
        Keyword.merge([pagination: :none], options)
      )

  @doc """
  Return a count of locations.

  ## Example

    iex> ShopifyAPI.REST.Location.count(auth)
    {:ok, integer = count}
  """
  def count(%AuthToken{} = auth, params \\ []), do: REST.get(auth, "locations/count.json", params)

  @doc """
  Returns a list of inventory levels for a location.

  ## Example

    iex> ShopifyAPI.REST.Location.inventory_levels(auth, integer)
    {:ok, %{} = inventory_levels}
  """
  def inventory_levels(%AuthToken{} = auth, location_id, params \\ [], options \\ []),
    do: REST.get(auth, "locations/#{location_id}/inventory_levels.json", params, options)
end
