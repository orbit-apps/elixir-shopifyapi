defmodule ShopifyAPI.AppServer do
  use GenServer
  require Logger

  @name :shopify_api_app_server

  def start_link(_opts) do
    Logger.info(fn -> "Starting #{__MODULE__}..." end)

    pid = GenServer.start_link(__MODULE__, %{}, name: @name)
    call_initializer(app_server_config(:initializer))
    pid
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

    # TODO should this be in a seperate process? It could tie up the GenServer
    persist(app_server_config(:persistance), name, Map.get(new_state, name))

    {:noreply, new_state}
  end

  @impl true
  def handle_call(:all, _caller, state), do: {:reply, state, state}

  @impl true
  def handle_call({:get, name}, _caller, state), do: {:reply, Map.fetch(state, name), state}

  @impl true
  def handle_call(:count, _caller, state), do: {:reply, Enum.count(state), state}

  def app_server_config(key), do: Application.get_env(:shopify_api, ShopifyAPI.AppServer)[key]

  def call_initializer({module, function, _}) when is_atom(module) and is_atom(function),
    do: apply(module, function, [])

  defp call_initializer(_), do: %{}

  defp persist({module, function, _}, key, value) when is_atom(module) and is_atom(function),
    do: apply(module, function, [key, value])

  defp persist(_, _, _), do: nil
end
