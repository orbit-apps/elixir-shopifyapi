defmodule ShopifyApi.ShopServer do
  use GenServer
  import Logger, only: [info: 1]
  alias ShopifyApi.Shop

  @name :shopify_shop_server

  def start_link do
    info("Starting Shopify Shop Server...")
    state = Application.get_env(:shopify_api, Shop)
    GenServer.start_link(__MODULE__, state, name: @name)
  end

  def all do
    GenServer.call(@name, :all)
  end

  def get(domain) do
    GenServer.call(@name, {:get, domain})
  end

  def count do
    GenServer.call(@name, :count)
  end

  def set(%{domain: domain} = new_values) do
    GenServer.cast(@name, {:set, domain, new_values})
  end

  #
  # Callbacks
  #

  def init(state), do: {:ok, state}

  def handle_cast({:set, domain, new_values}, %Shop{} = state) do
    new_state =
      Map.update(state, domain, %Shop{domain: domain}, fn t -> Map.merge(t, new_values) end)

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
