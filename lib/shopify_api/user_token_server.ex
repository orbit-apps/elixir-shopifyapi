defmodule ShopifyAPI.UserTokenServer do
  @moduledoc """
  Write-through cache for UserToken structs.
  """

  use GenServer

  alias ShopifyAPI.Config
  alias ShopifyAPI.UserToken

  @table __MODULE__
  @type t :: UserToken.t()
  @type ok_t :: {:ok, t()}
  @type error_not_found :: {:error, :user_token_not_found}

  def all do
    @table
    |> :ets.tab2list()
    |> Map.new()
  end

  @spec count() :: integer()
  def count, do: :ets.info(@table, :size)

  @spec set(UserToken.t()) :: :ok
  @spec set(UserToken.t(), boolean()) :: :ok
  def set(token, should_persist \\ true) when is_struct(token, UserToken) do
    :ets.insert(@table, {{token.shop_name, token.app_name, token.associated_user_id}, token})
    if should_persist, do: do_persist(token)
    :ok
  end

  @spec get(String.t(), String.t(), integer()) :: ok_t() | error_not_found()
  def get(myshopify_domain, app_name, user_id)
      when is_binary(myshopify_domain) and is_binary(app_name) and is_number(user_id) do
    case :ets.lookup(@table, {myshopify_domain, app_name, user_id}) do
      [{_key, token}] -> {:ok, token}
      [] -> {:error, :user_token_not_found}
    end
  end

  @spec get_valid(String.t(), String.t(), integer()) :: ok_t() | {:error, :invalid_user_token}
  def get_valid(myshopify_domain, app_name, user_id),
    do: myshopify_domain |> get(app_name, user_id) |> validate()

  @spec validate(ok_t() | error_not_found()) :: ok_t() | {:error, :invalid_user_token}
  def validate({:ok, user_token}) do
    now = DateTime.to_unix(DateTime.utc_now())

    if user_token.timestamp + user_token.expires_in >= now do
      {:ok, user_token}
    else
      {:error, :invalid_user_token}
    end
  end

  def validate(_), do: {:error, :invalid_user_token}

  def get_for_shop(shop) when is_binary(shop) do
    match_spec = [{{{shop, :_, :_}, :"$1"}, [], [:"$1"]}]
    :ets.select(@table, match_spec)
  end

  def get_for_app(app) when is_binary(app) do
    match_spec = [{{{:_, app, :_}, :"$1"}, [], [:"$1"]}]
    :ets.select(@table, match_spec)
  end

  @spec delete(String.t(), String.t()) :: :ok
  def delete(myshopify_domain, app) do
    :ets.delete(@table, {myshopify_domain, app})
    :ok
  end

  def drop_all, do: :ets.delete_all_objects(@table)

  ## GenServer Callbacks

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @impl GenServer
  def init(:ok) do
    create_table!()
    for token when is_struct(token, UserToken) <- do_initialize(), do: set(token, false)
    {:ok, :no_state}
  end

  ## Private Helpers

  defp create_table! do
    :ets.new(@table, [
      :set,
      :public,
      :named_table,
      read_concurrency: true
    ])
  end

  # Calls a configured initializer to obtain a list of AuthTokens.
  defp do_initialize do
    case Config.lookup(__MODULE__, :initializer) do
      {module, function, args} -> apply(module, function, args)
      {module, function} -> apply(module, function, [])
      _ -> []
    end
  end

  # Attempts to persist an UserToken if a persistence callback is configured
  defp do_persist(token) when is_struct(token, UserToken) do
    key = UserToken.create_key(token)

    case Config.lookup(__MODULE__, :persistence) do
      {module, function, args} -> apply(module, function, [key, token | args])
      {module, function} -> apply(module, function, [key, token])
      _ -> nil
    end
  end
end
