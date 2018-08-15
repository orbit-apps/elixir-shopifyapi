defmodule ShopifyAPI.ThrottleServer do
  use GenServer
  require Logger

  alias ShopifyAPI.AuthToken

  @name :shopify_api_throttle_server
  @shopify_call_limit_header "X-Shopify-Shop-Api-Call-Limit"
  @over_limit_status_code 429

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

  #
  # Callbacks
  #

  @impl true
  def init(state) do
    :ets.new(@name, [:named_table, :public])
    {:ok, state}
  end
end
