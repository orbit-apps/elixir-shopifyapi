defmodule ShopifyAPI.AuthTokenServer do
  @moduledoc "Write-through cache for AuthToken structs."

  use GenServer

  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.Config

  @table __MODULE__

  def all do
    @table
    |> :ets.tab2list()
    |> Map.new()
  end

  @spec count() :: integer()
  def count, do: :ets.info(@table, :size)

  @spec set(AuthToken.t()) :: :ok
  def set(%AuthToken{} = token, persist? \\ true) do
    :ets.insert(@table, {{token.shop_name, token.app_name}, token})
    if persist?, do: do_persist(token)
    :ok
  end

  @spec get(String.t(), String.t()) :: {:ok, AuthToken.t()} | {:error, String.t()}
  def get(shop, app) when is_binary(shop) and is_binary(app) do
    case :ets.lookup(@table, {shop, app}) do
      [{_key, token}] -> {:ok, token}
      [] -> {:error, "Auth token for #{shop}:#{app} could not be found."}
    end
  end

  def get_for_shop(shop) when is_binary(shop) do
    match_spec = [{{{shop, :_}, :"$1"}, [], [:"$1"]}]
    :ets.select(@table, match_spec)
  end

  def get_for_app(app) when is_binary(app) do
    match_spec = [{{{:_, app}, :"$1"}, [], [:"$1"]}]
    :ets.select(@table, match_spec)
  end

  def drop_all do
    :ets.delete_all_objects(@table)
  end

  ## GenServer Callbacks

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl GenServer
  def init(:ok) do
    create_table!()
    for %AuthToken{} = shop <- do_initialize(), do: set(shop, false)
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

  # Calls a configured initializer to obtain a list of AuthTokens.
  defp do_initialize do
    case Config.lookup(__MODULE__, :initializer) do
      {module, function, args} -> apply(module, function, args)
      {module, function} -> apply(module, function, [])
      _ -> []
    end
  end

  # Attempts to persist an AuthToken if a persistence callback is configured
  defp do_persist(%AuthToken{} = token) do
    key = AuthToken.create_key(token)

    case Config.lookup(__MODULE__, :persistence) do
      {module, function, args} -> apply(module, function, [key, token | args])
      {module, function} -> apply(module, function, [key, token])
      _ -> nil
    end
  end
end
