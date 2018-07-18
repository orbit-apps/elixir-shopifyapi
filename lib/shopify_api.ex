defmodule ShopifyAPI do
  @sleep_time 0.2
  @max_tries 10
  @bad_status_code 429

  def request(func, max_tries \\ @max_tries, depth \\ 1)

  def request(func, max_tries, depth) when is_function(func) and max_tries == depth,
    do: func.()

  def request(func, max_tries, depth) when is_function(func) do
    case func.() do
      {:error, %{status_code: @bad_status_code}} ->
        :timer.sleep(@sleep_time)
        request(func, max_tries, depth)

      resp ->
        resp
    end
  end
end
