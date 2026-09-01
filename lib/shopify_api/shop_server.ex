defmodule ShopifyAPI.ShopServer do
  @moduledoc """
  Write-through cache for `ShopifyAPI.Shop` structs, keyed by myshopify domain.

  `ShopifyAPI.AuthTokenServer` documents the caching design and the initializer/persistence
  contract the four servers share. What differs here:

    - `set/2` does **not** persist unless you ask it to, the opposite of the token caches. The
      struct holds only a domain, so there is usually nothing worth writing out
    - `get_or_create/2` returns a shop for any domain, caching a new struct on a miss — and it
      *does* persist by default
    - `get/1` returns a bare `:error` rather than an `{:error, reason}` tuple

  `ShopifyAPI.Router` populates this during install, and `delete/1` clears a shop on uninstall.
  """

  use GenServer

  alias ShopifyAPI.Config
  alias ShopifyAPI.Shop

  @table __MODULE__

  def all do
    @table
    |> :ets.tab2list()
    |> Map.new()
  end

  @spec count() :: integer()
  def count, do: :ets.info(@table, :size)

  @spec set(Shop.t(), boolean()) :: :ok
  def set(%Shop{domain: domain} = shop, should_persist \\ false) do
    :ets.insert(@table, {domain, shop})
    if should_persist, do: do_persist(shop)
    :ok
  end

  @spec get(String.t()) :: {:ok, Shop.t()} | :error
  def get(domain) do
    case :ets.lookup(@table, domain) do
      [{^domain, shop}] -> {:ok, shop}
      [] -> :error
    end
  end

  @spec get_or_create(String.t(), boolean()) :: {:ok, Shop.t()}
  def get_or_create(domain, should_persist \\ true) do
    case get(domain) do
      {:ok, _} = resp ->
        resp

      :error ->
        shop = %Shop{domain: domain}
        set(shop, should_persist)
        {:ok, shop}
    end
  end

  @spec delete(String.t()) :: :ok
  def delete(domain) do
    true = :ets.delete(@table, domain)
    :ok
  end

  ## GenServer Callbacks

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @impl GenServer
  def init(:ok) do
    create_table!()
    for shop when is_struct(shop, Shop) <- do_initialize(), do: set(shop, false)
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

  # Calls a configured initializer to obtain a list of Shops.
  defp do_initialize do
    case Config.lookup(__MODULE__, :initializer) do
      {module, function, args} -> apply(module, function, args)
      {module, function} -> apply(module, function, [])
      _ -> []
    end
  end

  # Attempts to persist a Shop if a persistence callback is configured
  defp do_persist(%Shop{domain: domain} = shop) do
    case Config.lookup(__MODULE__, :persistence) do
      {module, function, args} -> apply(module, function, [domain, shop | args])
      {module, function} -> apply(module, function, [domain, shop])
      _ -> nil
    end
  end
end
