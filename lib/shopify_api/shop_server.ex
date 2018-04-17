defmodule ShopifyApi.ShopServer do
  use GenServer
  import Logger, only: [info: 1]
  alias ShopifyApi.Shop

  @name :shopify_shop_server

  def start_link do
    info("Starting Shopify Shop Server...")
    state = Application.get_env(:shopify_api, Shop)
    GenServer.start_link(__MODULE__, Map.merge(%Shop{}, state), name: @name)
  end

  def get do
    GenServer.call(@name, :get)
  end

  def set(new_values) do
    GenServer.cast(@name, {:set, new_values})
  end

  #
  # Callbacks
  #

  def init(state), do: {:ok, state}

  def handle_cast({:set, new_values}, %Shop{} = state) do
    {:noreply, Map.merge(state, new_values)}
  end

  def handle_call(:get, _caller, state) do
    {:reply, state, state}
  end
end
