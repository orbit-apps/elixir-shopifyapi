defmodule ShopifyAPI.AuthTokenServer do
  use GenServer
  require Logger
  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.EventPipe.EventQueue

  @name :shopify_api_auth_token_server

  def start_link(_opts) do
    Logger.info(fn -> "Starting #{__MODULE__} ..." end)

    GenServer.start_link(__MODULE__, %{}, name: @name)
  end

  @spec all :: map()
  def all, do: GenServer.call(@name, :all)

  @doc """
  Fetch's a shop's AuthToken from the AuthTokenServer. A myshopify domain
  and an app must be provided.

  ```
  iex(6)> ShopifyAPI.AuthTokenServer.get("a-shop.myshopify.com", "my_app")
  {:ok, %ShopifyAPI.AuthToken{
     app_name: "my_app",
     shop_name: "a-shop.myshopify.com",
     ...
    }}
  iex(7)> ShopifyAPI.AuthTokenServer.get("not-in-memory.myshopify.com", "my_app")
  {:error, "Auth token for not-in-memory.myshopify.com:my_app could not be found."}
  ```
  """
  @spec get(String.t(), String.t()) :: {:ok, AuthToken.t()} | {:error, any()}
  def get(shop, app), do: GenServer.call(@name, {:get, AuthToken.create_key(shop, app)})

  @spec get_for_app(String.t()) :: list(AuthToken.t())
  def get_for_app(app), do: GenServer.call(@name, {:get_for_app, app})

  @spec get_for_shop(String.t()) :: list(AuthToken.t())
  def get_for_shop(shop), do: GenServer.call(@name, {:get_for_shop, shop})

  @spec count :: integer()
  def count, do: GenServer.call(@name, :count)

  @spec set(AuthToken.t(), boolean()) :: any()
  def set(token, call_persist \\ true)

  def set(%AuthToken{shop_name: shop, app_name: app} = token, false) do
    GenServer.cast(@name, {:set, AuthToken.create_key(shop, app), token})
    Task.start(fn -> EventQueue.subscribe(token) end)
  end

  def set(%AuthToken{shop_name: shop, app_name: app} = token, true) do
    set(token, false)

    # TODO should this be in a seperate process? It could tie up the GenServer
    persist(
      auth_token_server_config(:persistance),
      AuthToken.create_key(shop, app),
      token
    )
  end

  def set(token, call_persist) when is_map(token),
    do: set(struct(AuthToken, Map.to_list(token)), call_persist)

  def drop_all, do: GenServer.cast(@name, :drop_all)

  #
  # Callbacks
  #

  @impl true
  def init(state), do: {:ok, state, {:continue, :initialize}}

  @impl true
  @callback handle_continue(atom, map) :: tuple
  def handle_continue(:initialize, state) do
    new_state =
      :initializer
      |> auth_token_server_config()
      |> call_initializer()
      |> Enum.reduce(state, &Map.put(&2, AuthToken.create_key(&1.shop_name, &1.app_name), &1))

    {:noreply, new_state}
  end

  @impl true
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

  @impl true
  def handle_cast(:drop_all, _), do: {:noreply, %{}}

  @impl true
  def handle_call(:all, _caller, state), do: {:reply, state, state}

  @impl true
  def handle_call({:get, key}, _caller, state) do
    case Map.fetch(state, key) do
      {:ok, _token} = token_response ->
        {:reply, token_response, state}

      :error ->
        {:reply, {:error, "Auth token for #{key} could not be found."}, state}
    end
  end

  @impl true
  def handle_call({:get_for_app, app}, _caller, state) do
    vals =
      state
      |> Map.values()
      |> Enum.filter(fn t -> t.app_name == app end)

    {:reply, vals, state}
  end

  @impl true
  def handle_call({:get_for_shop, shop}, _caller, state) do
    vals =
      state
      |> Map.values()
      |> Enum.filter(fn t -> t.shop_name == shop end)

    {:reply, vals, state}
  end

  @impl true
  def handle_call(:count, _caller, state), do: {:reply, Enum.count(state), state}

  defp auth_token_server_config(key),
    do: Application.get_env(:shopify_api, ShopifyAPI.AuthTokenServer)[key]

  defp call_initializer({module, function, _}) when is_atom(module) and is_atom(function),
    do: apply(module, function, [])

  defp call_initializer(_), do: []

  def persist({module, function, _}, key, value) when is_atom(module) and is_atom(function),
    do: apply(module, function, [key, value])

  def persist(_, _, _), do: nil
end
