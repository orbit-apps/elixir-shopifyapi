defmodule ShopifyAPI.ThrottleServer do
  use GenServer
  require Logger

  alias ShopifyAPI.AuthToken

  @name :shopify_api_throttle_server
  @shopify_call_limit_header "X-Shopify-Shop-Api-Call-Limit"
  @over_limit_status_code 429

  def start_link(_opts) do
    Logger.info(fn -> "Starting #{__MODULE__} ..." end)

    GenServer.start_link(__MODULE__, %{}, name: @name)
  end

  def all, do: GenServer.call(@name, :all)

  def get(%AuthToken{} = token) do
    GenServer.call(@name, {:get, AuthToken.create_key(token), ShopifyAPI.request_bucket(token)})
  end

  # Do nothing
  def set(nil, _token), do: nil

  def set(availble_count, %AuthToken{} = token),
    do: GenServer.cast(@name, {:set, AuthToken.create_key(token), availble_count})

  def update_api_call_limit(http_response, token) do
    http_response
    |> limit_header_or_status_code
    |> get_api_call_limit
    |> set(token)
  end

  # API Overlimit error code
  defp limit_header_or_status_code(%{status_code: @over_limit_status_code()}),
    do: :over_limit

  defp limit_header_or_status_code(%{headers: headers}),
    do: Enum.find(headers, fn header -> elem(header, 0) == @shopify_call_limit_header end)

  defp limit_header_or_status_code(_conn), do: nil

  defp get_api_call_limit(nil), do: nil

  defp get_api_call_limit(:over_limit), do: 0

  defp get_api_call_limit(header) do
    # comes in the form "1/40": 1 taken of 40
    header
    |> get_value_from_header
    |> String.split("/")
    |> Enum.map(&String.to_integer/1)
    |> calculate_available
  end

  defp get_value_from_header({_, value}), do: value

  defp calculate_available([used, total]), do: total - used

  def init(state), do: {:ok, state}

  def handle_call(:all, _caller, state) do
    {:reply, state, state}
  end

  def handle_call({:get, key, default}, _caller, state) do
    {:reply, Map.get(state, key, {default, :no_time}), state}
  end

  def handle_cast({:set, key, new_value}, %{} = state) do
    {:noreply, Map.put(state, key, {new_value, NaiveDateTime.utc_now()})}
  end
end
