defmodule ShopifyAPI.REST.Event do
  @moduledoc """
  ShopifyAPI REST API Event resource

  More via: https://help.shopify.com/api/reference/events/event#index
  """

  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST

  @doc """
  Return a list of all Events.

  ## Example

      iex> ShopifyAPI.REST.Event.all(auth)
      {:ok, [%{}, ...] = events}
  """
  def all(%AuthToken{} = auth, params \\ [], options \\ []),
    do: REST.get(auth, "events.json", params, options)

  @doc """
  Get a single event.

  ## Example

      iex> ShopifyAPI.REST.Event.get(auth, integer)
      {:ok, %{} = event}
  """
  def get(%AuthToken{} = auth, event_id, params \\ [], options \\ []),
    do:
      REST.get(
        auth,
        "events/#{event_id}.json",
        params,
        Keyword.merge([pagination: :none], options)
      )

  @doc """
  Get a count of all Events.

  ## Example

      iex> ShopifyAPI.REST.Event.count(auth)
      {:ok, integer = events}
  """
  def count(%AuthToken{} = auth, params \\ [], options \\ []),
    do: REST.get(auth, "events/count.json", params, Keyword.merge([pagination: :none], options))
end
