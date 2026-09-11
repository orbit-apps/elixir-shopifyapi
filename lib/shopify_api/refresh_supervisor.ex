defmodule ShopifyAPI.RefreshSupervisor do
  @moduledoc """
  Supervises the processes that refresh expiring offline access tokens.

  A separate subtree so that refresh failures (which come in bursts when Shopify is unwell)
  do not exhaust the restart budget shared by the cache servers.

  Two children, both idle until a refresh is requested:

    - `ShopifyAPI.RefreshRegistry` — tracks the in-flight refresh per `{shop_name, app_name}`
    - `ShopifyAPI.RefreshTaskSupervisor` — runs background refresh tasks (`:temporary`, never
      restarted)

  Starts unconditionally. The `:expiring` flag controls new token requests; whether a token
  is refreshed depends on it carrying a refresh token.
  """

  use Supervisor

  def start_link(_opts), do: Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)

  @impl Supervisor
  def init(:ok) do
    children = [
      {Registry, keys: :unique, name: ShopifyAPI.RefreshRegistry},
      {Task.Supervisor, name: ShopifyAPI.RefreshTaskSupervisor}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
