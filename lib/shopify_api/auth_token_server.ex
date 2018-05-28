defmodule ShopifyApi.AuthTokenServer do
  use GenServer
  require Logger

  @name :shopify_api_auth_token_server

  def start_link do
    Logger.info(fn -> "Starting #{__MODULE__}..." end)
    GenServer.start_link(__MODULE__, %{}, name: @name)
  end

  def all do
    GenServer.call(@name, :all)
  end

  def get(shop, app) do
    GenServer.call(@name, {:get, create_key(shop, app)})
  end

  def get_for_app(app) do
    GenServer.call(@name, {:get_for_app, app})
  end

  @spec count :: integer
  def count do
    GenServer.call(@name, :count)
  end

  def set(shop, app, new_values) do
    token = Map.merge(%{app_name: app, shop_name: shop}, new_values)
    GenServer.cast(@name, {:set, create_key(shop, app), token})
  end

  defp create_key(shop, app) do
    "#{shop}:#{app}"
  end

  #
  # Callbacks
  #

  def init(state), do: {:ok, state}

  @callback handle_cast(map, map) :: tuple
  def handle_cast({:set, key, new_values}, %{} = state) do
    new_state =
      update_in(state, [key], fn t ->
        case t do
          nil -> Map.merge(%ShopifyApi.AuthToken{}, new_values)
          _ -> Map.merge(t, new_values)
        end
      end)

    {:noreply, new_state}
  end

  def handle_call(:all, _caller, state) do
    {:reply, state, state}
  end

  def handle_call({:get, key}, _caller, state) do
    {:reply, Map.fetch(state, key), state}
  end

  def handle_call({:get_for_app, app}, _caller, state) do
    vals =
      state
      |> Map.values()
      |> Enum.filter(fn t -> t.app_name == app end)

    {:reply, vals, state}
  end

  def handle_call(:count, _caller, state) do
    {:reply, Enum.count(state), state}
  end
end
