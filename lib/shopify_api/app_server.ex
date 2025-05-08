defmodule ShopifyAPI.AppServer do
  @moduledoc """
  Write-through cache for App structs.
  """

  use GenServer

  alias ShopifyAPI.App
  alias ShopifyAPI.Config

  @table __MODULE__
  @name __MODULE__
  @single_app_install Application.compile_env(:shopify_api, :app_server, :single_app) ==
                        :single_app || true

  if @single_app_install do
    @spec set(App.t()) :: :ok
    def set(%App{} = app) do
      GenServer.cast(@name, {:app, app})
      do_persist(app)
      :ok
    end

    @spec set(String.t(), App.t()) :: :ok
    def set(_, app), do: set(app)

    @spec get(String.t()) :: {:ok, App.t()} | :error
    def get(_name \\ ""), do: GenServer.call(@name, :app)

    def get_by_client_id(client_id), do: get(client_id)

    def mode, do: :single_app
  else
    def all, do: @table |> :ets.tab2list() |> Map.new()

    @spec count() :: integer()
    def count, do: :ets.info(@table, :size)

    @spec set(App.t()) :: :ok
    def set(%App{name: name} = app), do: set(name, app)

    @spec set(String.t(), App.t()) :: :ok
    def set(name, app) when is_binary(name) and is_struct(app, App) do
      :ets.insert(@table, {name, app})
      do_persist(app)
      :ok
    end

    @spec get(String.t()) :: {:ok, App.t()} | :error
    def get(name) when is_binary(name) do
      case :ets.lookup(@table, name) do
        [{^name, app}] -> {:ok, app}
        [] -> :error
      end
    end

    def get_by_client_id(client_id) do
      case :ets.match_object(@table, {:_, %{client_id: client_id}}) do
        [{_, app}] -> {:ok, app}
        [] -> :error
      end
    end

    def mode, do: :multi_app
  end

  ## GenServer Callbacks

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: @name)

  @impl GenServer
  def init(:ok) do
    create_table!()
    for %App{} = app <- do_initialize(), do: set(app)
    {:ok, %{}}
  end

  @impl GenServer
  def handle_cast({:app, app}, state), do: {:noreply, Map.put(state, :app, app)}

  @impl GenServer
  def handle_call(:app, _from, %{app: app} = state), do: {:reply, {:ok, app}, state}
  def handle_call(:app, _from, state), do: {:reply, :error, state}

  defp create_table! do
    :ets.new(@table, [
      :set,
      :public,
      :named_table,
      read_concurrency: true
    ])
  end

  # Calls a configured initializer to obtain a list of Apps.
  defp do_initialize do
    case Config.lookup(__MODULE__, :initializer) do
      {module, function, args} -> apply(module, function, args)
      {module, function} -> apply(module, function, [])
      _ -> []
    end
  end

  # Attempts to persist a App if a persistence callback is configured
  defp do_persist(%App{name: name} = app) do
    case Config.lookup(__MODULE__, :persistence) do
      {module, function, args} -> apply(module, function, [name, app | args])
      {module, function} -> apply(module, function, [name, app])
      _ -> nil
    end
  end
end
