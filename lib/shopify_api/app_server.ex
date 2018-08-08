defmodule ShopifyAPI.AppServer do
  use GenServer
  require Logger

  @name :shopify_api_app_server

  def start_link(_opts) do
    Logger.info(fn -> "Starting #{__MODULE__}..." end)
    state = Application.get_env(:shopify_api, ShopifyAPI.App)
    state = for {k, v} <- state, into: %{}, do: {k, struct(ShopifyAPI.App, v)}
    GenServer.start_link(__MODULE__, state, name: @name)
  end

  def all, do: GenServer.call(@name, :all)

  def get(name), do: GenServer.call(@name, {:get, name})

  @spec count :: integer
  def count, do: GenServer.call(@name, :count)

  def set(name, new_values), do: GenServer.cast(@name, {:set, name, new_values})

  #
  # Callbacks
  #

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  @callback handle_cast(map, map) :: tuple
  def handle_cast({:set, name, new_values}, %{} = state) do
    new_state =
      update_in(state, [name], fn t ->
        case t do
          nil -> Map.merge(%ShopifyAPI.App{}, new_values)
          _ -> Map.merge(t, new_values)
        end
      end)

    {:noreply, new_state}
  end

  @impl true
  def handle_call(:all, _caller, state), do: {:reply, state, state}

  @impl true
  def handle_call({:get, name}, _caller, state), do: {:reply, Map.fetch(state, name), state}

  @impl true
  def handle_call(:count, _caller, state), do: {:reply, Enum.count(state), state}
end
