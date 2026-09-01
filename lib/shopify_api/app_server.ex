defmodule ShopifyAPI.AppServer do
  @moduledoc """
  Write-through cache for `ShopifyAPI.App` structs, keyed by app name.

  One deployment can serve several Shopify apps, and this cache is what makes that work. Each
  entry carries its own client id, secret and scopes, so a companion app or a second listing
  sharing your codebase is just another `ShopifyAPI.App` returned by the initializer. That is
  also why so much of the library is app-aware: `ShopifyAPI.Router` takes the app name in the
  path, `ShopifyAPI.AuthTokenServer` keys tokens by `{shop, app}` so one shop can install
  several of yours, and `ShopifyAPI.Plugs.Webhook` needs the app name appended to its URL
  because Shopify does not say which app a webhook is for.

  Apps are looked up by name with `get/1`, and by client id with `get_by_client_id/1` — which
  is how the `aud` claim of a session token is resolved back to the app that issued it.

  Unlike the token caches this one is usually seeded entirely from configuration or your own
  storage and then left alone; an app's credentials change far less often than its shops do.
  `ShopifyAPI.AuthTokenServer` documents the caching design and the initializer/persistence
  contract the four servers share. The differences here are:

    - the cache key is the app's `:name`, and it is also what the persistence callback receives
      as its first argument
    - `set/1` and `set/2` always persist. There is no opt-out flag, which means the initializer
      writes every app it loads straight back out again on boot — keep your persistence
      callback idempotent
    - lookups return a bare `:error` rather than an `{:error, reason}` tuple
  """

  use GenServer

  alias ShopifyAPI.App
  alias ShopifyAPI.Config

  @table __MODULE__

  def all, do: @table |> :ets.tab2list() |> Map.new()

  @spec count() :: integer()
  def count, do: :ets.info(@table, :size)

  @spec set(App.t()) :: :ok
  def set(%App{name: name} = app), do: set(name, app)

  @spec set(String.t(), App.t()) :: :ok
  def set(name, app) when is_binary(name) and is_struct(app, App) do
    :ets.insert(@table, {name, app})
    do_persist(app)
    :ok
  end

  @spec get(String.t()) :: {:ok, App.t()} | :error
  def get(name) when is_binary(name) do
    case :ets.lookup(@table, name) do
      [{^name, app}] -> {:ok, app}
      [] -> :error
    end
  end

  def get_by_client_id(client_id) do
    case :ets.match_object(@table, {:_, %{client_id: client_id}}) do
      [{_, app}] -> {:ok, app}
      [] -> :error
    end
  end

  ## GenServer Callbacks

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @impl GenServer
  def init(:ok) do
    create_table!()
    for %App{} = app <- do_initialize(), do: set(app)
    {:ok, :no_state}
  end

  ## Private Helpers

  defp create_table! do
    :ets.new(@table, [
      :set,
      :public,
      :named_table,
      read_concurrency: true
    ])
  end

  # Calls a configured initializer to obtain a list of Apps.
  defp do_initialize do
    case Config.lookup(__MODULE__, :initializer) do
      {module, function, args} -> apply(module, function, args)
      {module, function} -> apply(module, function, [])
      _ -> []
    end
  end

  # Attempts to persist a App if a persistence callback is configured
  defp do_persist(%App{name: name} = app) do
    case Config.lookup(__MODULE__, :persistence) do
      {module, function, args} -> apply(module, function, [name, app | args])
      {module, function} -> apply(module, function, [name, app])
      _ -> nil
    end
  end
end
