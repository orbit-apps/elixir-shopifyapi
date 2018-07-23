defmodule ShopifyAPI.AuthTokenServer do
  use GenServer
  require Logger
  alias ShopifyAPI.AuthToken

  @name :shopify_api_auth_token_server

  def start_link(_opts) do
    Logger.info(fn -> "Starting #{__MODULE__} ..." end)

    pid = GenServer.start_link(__MODULE__, %{}, name: @name)
    call_initializer(auth_token_server_config(:initializer))
    pid
  end

  def all, do: GenServer.call(@name, :all)

  def get(shop, app), do: GenServer.call(@name, {:get, AuthToken.create_key(shop, app)})

  def get_for_app(app), do: GenServer.call(@name, {:get_for_app, app})

  @spec count :: integer
  def count, do: GenServer.call(@name, :count)

  def set(token, call_persist \\ true)

  def set(%AuthToken{shop_name: shop, app_name: app} = token, false),
    do: GenServer.cast(@name, {:set, AuthToken.create_key(shop, app), token})

  def set(%AuthToken{shop_name: shop, app_name: app} = token, true) do
    set(token, false)

    Task.start(fn ->
      __MODULE__.persist(
        auth_token_server_config(:persistance),
        AuthToken.create_key(shop, app),
        token
      )
    end)
  end

  def set(token, call_persist) when is_map(token),
    do: set(struct(AuthToken, Map.to_list(token)), call_persist)

  def drop_all, do: GenServer.cast(@name, :drop_all)

  def auth_token_server_config(key),
    do: Application.get_env(:shopify_api, ShopifyAPI.AuthTokenServer)[key]

  def call_initializer({module, function, _}) when is_atom(module) and is_atom(function),
    do: apply(module, function, [])

  def call_initializer(_), do: %{}

  def persist({module, function, _}, key, value) when is_atom(module) and is_atom(function),
    do: apply(module, function, [key, value])

  def persist(_, _, _), do: nil

  #
  # Callbacks
  #

  def init(state), do: {:ok, state}

  @callback handle_cast(any, map) :: tuple
  def handle_cast({:set, key, new_values}, %{} = state) do
    new_state =
      update_in(state, [key], fn t ->
        case t do
          nil -> Map.merge(%ShopifyAPI.AuthToken{}, new_values)
          _ -> Map.merge(t, new_values)
        end
      end)

    {:noreply, new_state}
  end

  def handle_cast(:drop_all, _) do
    {:noreply, %{}}
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
