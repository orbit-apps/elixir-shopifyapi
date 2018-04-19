defmodule ShopifyApi.AuthTokenServer do
  use GenServer
  import Logger, only: [info: 1]

  @name :shopify_api_auth_token_server

  def start_link do
    info("Starting #{__MODULE__}...")
    GenServer.start_link(__MODULE__, %{}, name: @name)
  end

  def all do
    GenServer.call(@name, :all)
  end

  def get(domain) do
    GenServer.call(@name, {:get, domain})
  end

  @spec count :: integer
  def count do
    GenServer.call(@name, :count)
  end

  def set(domain, new_values) do
    GenServer.cast(@name, {:set, domain, new_values})
  end

  #
  # Callbacks
  #

  def init(state), do: {:ok, state}

  @callback handle_cast(map, map) :: tuple
  def handle_cast({:set, domain, new_values}, %{} = state) do
    new_state =
      Map.update(state, domain, %ShopifyApi.AuthToken{shop: domain}, fn t ->
        Map.merge(t, new_values)
      end)

    {:noreply, new_state}
  end

  def handle_call(:all, _caller, state) do
    {:reply, state, state}
  end

  def handle_call({:get, domain}, _caller, state) do
    {:reply, Map.fetch(state, domain), state}
  end

  def handle_call(:count, _caller, state) do
    {:reply, Enum.count(state), state}
  end
end
