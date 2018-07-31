defmodule ShopifyAPI.Throttled do
  require Logger

  alias ShopifyAPI.ThrottleServer

  @request_max_tries 10

  def request(func, token, max_tries \\ @request_max_tries, depth \\ 1)

  def request(func, _token, max_tries, depth) when is_function(func) and max_tries == depth,
    do: func.()

  def request(func, token, max_tries, depth) when is_function(func) do
    over_limit_status_code = ShopifyAPI.over_limit_status_code()

    case token
         |> ThrottleServer.get()
         |> make_request(func, ShopifyAPI.requests_per_second(token)) do
      {:error, %{status_code: ^over_limit_status_code}} ->
        request(func, token, max_tries, depth + 1)

      resp ->
        resp
    end
  end

  def make_request(t, func, req_sec, sleep_impl \\ &:timer.sleep/1)

  # No limit found in the store, make a request
  def make_request({_, last_check}, func, _, _) when last_check == :no_time, do: func.()

  # Haven't hit our limit yet, make a request
  def make_request({limit, _}, func, _, _) when limit > 0, do: func.()

  def make_request({_, last_check}, func, req_sec, sleep_impl) do
    case last_check_is_stale?(last_check, req_sec) do
      :lt ->
        func.()

      _ ->
        sleep_impl.(round(1_000 / req_sec))
        func.()
    end
  end

  defp last_check_is_stale?(last_check, req_sec) do
    last_check
    |> NaiveDateTime.add(round(1_000 / req_sec), :millisecond)
    |> NaiveDateTime.compare(NaiveDateTime.utc_now())
  end
end
