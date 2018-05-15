defmodule ShopifyApi.Rest.Event do
  @moduledoc """
  ShopifyApi REST API Event resource

  More via: https://help.shopify.com/api/reference/events/event#index
  """

  alias ShopifyApi.AuthToken
  alias ShopifyApi.Rest.Request

  @doc """
  Return a list of all Events.

  ## Example

      iex> ShopifyApi.Rest.Event.all(auth)
      {:ok, { "events" => [] }}
  """
  def all(%AuthToken{} = auth) do
    Request.get(auth, "events.json")
  end

  @doc """
  Get a single event.

  ## Example

      iex> ShopifyApi.Rest.Event.get(auth, integer)
      {:ok, { "event" => %{} }}
  """
  def get(%AuthToken{} = auth, event_id) do
    Request.get(auth, "events/#{event_id}.json")
  end

  @doc """
  Get a count of all Events.

  ## Example

      iex> ShopifyApi.Rest.Event.count(auth)
      {:ok, { "events" => integer }}
  """
  def count(%AuthToken{} = auth) do
    Request.get(auth, "events/count.json")
  end
end
