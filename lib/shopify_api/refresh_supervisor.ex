defmodule ShopifyAPI.RefreshSupervisor do
  @moduledoc """
  Supervises the processes that refresh expiring offline access tokens and exchange permanent
  ones.

  A separate subtree so that refresh failures (which come in bursts when Shopify is unwell)
  do not exhaust the restart budget shared by the cache servers.

  Two children, both idle until a refresh or exchange is requested:

    - `ShopifyAPI.RefreshRegistry` — tracks the in-flight refresh or exchange per
      `{shop_name, app_name}`
    - `ShopifyAPI.RefreshTaskSupervisor` — runs background refresh and exchange tasks
      (`:temporary`, never restarted)

  Starts unconditionally. Whether a token is refreshed depends on it carrying a refresh token,
  whatever `:offline_tokens` is set to.
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
