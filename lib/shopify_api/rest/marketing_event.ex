defmodule ShopifyAPI.REST.MarketingEvent do
  @moduledoc """
  ShopifyAPI REST API MarketingEvent resource
  """

  require Logger
  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST.Request

  @doc """
  Return a list of all marketing events.

  ## Example

      iex> ShopifyAPI.REST.MarketingEvent.all(auth)
      {:ok, { "marketing_events" => [] }}
  """
  def all(%AuthToken{} = auth), do: Request.get(auth, "marketing_events.json")

  @doc """
  Get a count of all marketing events.

  ## Example

      iex> ShopifyAPI.REST.MarketingEvent.count(auth)
      {:ok, { "count" => integer }}
  """
  def count(%AuthToken{} = auth), do: Request.get(auth, "marketing_events/count.json")

  @doc """
  Get a single marketing event.

  ## Example

      iex> ShopifyAPI.REST.MarketingEvent.get(auth, integer)
      {:ok, { "marketing_event" => %{} }}
  """
  def get(%AuthToken{} = auth, marketing_event_id),
    do: Request.get(auth, "marketing_events/#{marketing_event_id}.json")

  @doc """
  Create a marketing event.

  ## Example

      iex> ShopifyAPI.REST.MarketingEvent.create(auth, map)
      {:ok, { "marketing_event" => %{} }}
  """
  def create(
        %AuthToken{} = auth,
        %{marketing_event: %{id: marketing_event_id}} = marketing_event
      ),
      do: Request.post(auth, "marketing_events/#{marketing_event_id}.json", marketing_event)

  @doc """
  Update a marketing event.

  ## Example

      iex> ShopifyAPI.REST.MarketingEvent.update(auth, map)
      {:ok, { "marketing_event" => %{} }}
  """
  def update(
        %AuthToken{} = auth,
        %{marketing_event: %{id: marketing_event_id}} = marketing_event
      ),
      do: Request.put(auth, "marketing_events/#{marketing_event_id}.json", marketing_event)

  @doc """
  Delete a marketing event.

  ## Example

      iex> ShopifyAPI.REST.MarketingEvent.delete(auth)
      {:ok, 200 }
  """
  def delete(%AuthToken{} = auth, marketing_event_id),
    do: Request.delete(auth, "marketing_events/#{marketing_event_id}.json")

  @doc """
  Creates a marketing engagements on a marketing event.

  NOTE: Not implemented.

  ## Example

  iex> ShopifyAPI.REST.MarketingEvent.create_engagement()
      {:error, "Not implemented" }
  """
  def create_engagement do
    Logger.warn("#{__MODULE__} error, resource not implemented.")
    {:error, "Not implemented"}
  end
end
