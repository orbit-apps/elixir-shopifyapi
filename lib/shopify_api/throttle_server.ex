defmodule ShopifyAPI.ThrottleServer do
  use GenServer
  require Logger

  alias ShopifyAPI.{AuthToken, CallLimit}

  @name :shopify_api_throttle_server

  @spec start_link(any) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(_opts) do
    Logger.info(fn -> "Starting #{__MODULE__} ..." end)

    GenServer.start_link(__MODULE__, @name, name: @name)
  end

  def all, do: :ets.tab2list(@name)

  def get(%AuthToken{} = token) do
    case :ets.lookup(@name, AuthToken.create_key(token)) do
      [] -> {ShopifyAPI.request_bucket(token), :no_time}
      result -> result |> List.first() |> Tuple.delete_at(0)
    end
  end

  # Do nothing
  def set(nil, _token), do: nil

  def set(availble_count, %AuthToken{} = token),
    do: :ets.insert(@name, {AuthToken.create_key(token), availble_count, NaiveDateTime.utc_now()})

  def update_api_call_limit(http_response, token) do
    http_response
    |> CallLimit.limit_header_or_status_code()
    |> CallLimit.get_api_call_limit()
    |> set(token)
  end

  #
  # Callbacks
  #

  @impl true
  def init(state) do
    :ets.new(@name, [:named_table, :public])
    {:ok, state}
  end
end
