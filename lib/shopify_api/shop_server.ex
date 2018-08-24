defmodule ShopifyAPI.ShopServer do
  use GenServer
  import Logger, only: [info: 1]
  alias ShopifyAPI.Shop

  @name :shopify_api_shop_server

  def start_link(_opts) do
    info("Starting #{__MODULE__}...")
    # TODO have some sane way to handle this config not existing
    state = Application.get_env(:shopify_api, ShopifyAPI.ShopServer)
    state = for {k, v} <- state, into: %{}, do: {k, struct(Shop, v)}
    GenServer.start_link(__MODULE__, state, name: @name)
  end

  def all, do: GenServer.call(@name, :all)

  def get(domain), do: GenServer.call(@name, {:get, domain})

  @spec count :: integer
  def count, do: GenServer.call(@name, :count)

  @spec set(%{:domain => any, any => any}) :: atom
  def set(%{domain: domain} = new_values), do: GenServer.cast(@name, {:set, domain, new_values})

  #
  # Callbacks
  #

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  @callback handle_cast(map, map) :: tuple
  def handle_cast({:set, domain, new_values}, %{} = state) do
    new_state = Map.update(state, domain, %Shop{domain: domain}, &Map.merge(&1, new_values))

    {:noreply, new_state}
  end

  @impl true
  def handle_call(:all, _caller, state), do: {:reply, state, state}

  @impl true
  def handle_call({:get, domain}, _caller, state), do: {:reply, Map.fetch(state, domain), state}

  @impl true
  def handle_call(:count, _caller, state), do: {:reply, Enum.count(state), state}
end
