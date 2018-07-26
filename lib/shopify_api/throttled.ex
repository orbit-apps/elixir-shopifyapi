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
        request(func, max_tries, depth)

      resp ->
        resp
    end
  end

  # No limit found in the store, make a request
  defp make_request({_limit, last_check}, func, _req_sec) when last_check == :no_time, do: func.()

  # Haven't hit our limit yet, make a request
  defp make_request({limit, _last_check}, func, _req_sec) when limit > 0, do: func.()

  defp make_request({_limit, last_check}, func, req_sec) do
    case compare_last_check(last_check, req_sec) do
      :gt ->
        func.()

      _ ->
        :timer.sleep(1_000 / req_sec)
        func.()
    end
  end

  defp compare_last_check(last_check, req_sec) do
    last_check
    |> NaiveDateTime.add(1_000 / req_sec, :millisecond)
    |> NaiveDateTime.compare(NaiveDateTime.utc_now())
  end
end
