defmodule Test.ShopifyAPI.ThrottledTest do
  use ExUnit.Case
  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.Throttled

  @token %AuthToken{app_name: "test", shop_name: "throttled", plus: false}

  def func, do: send(self(), :func_called)
  def sleep_impl(_), do: send(self(), :sleep_called)

  defmodule TrackerMock do
    def get(_, _), do: {100, 0}
    def api_hit_limit(_, _), do: {100, 0}

    def update_api_call_limit(_, _) do
      send(self(), :update_api_call_limit_called)
      {100, 0}
    end
  end

  describe "request/6" do
    test "recurses when func returns graphql throttled response" do
      func = fn ->
        send(self(), :func_called)
        {:error, %{body: %{"errors" => [%{"message" => "Throttled"}]}, status_code: 200}}
      end

      max_tries = 2
      Throttled.request(func, @token, max_tries, TrackerMock)
      for _ <- 1..max_tries, do: assert_received(:func_called)
    end

    test "updates api call limit and does not recurse when func returns success" do
      func = fn ->
        send(self(), :func_called)
        {:ok, %{status_code: 200}}
      end

      Throttled.request(func, @token, TrackerMock)

      assert_receive :update_api_call_limit_called
      assert_receive :func_called
      refute_receive :func_called
    end
  end

  describe "make_request/3" do
    test "if limit has room call right away" do
      Throttled.make_request({1, 0}, &func/0, &sleep_impl/1)
      assert_receive :func_called
    end

    test "does not sleep if there limit set 0 and there is no availability_delay" do
      Throttled.make_request({0, 0}, &func/0, &sleep_impl/1)
      refute_receive :sleep_called
    end

    test "sleeps if there limit set 0 and there is a availability_delay" do
      Throttled.make_request({0, 2_001}, &func/0, &sleep_impl/1)
      assert_receive :sleep_called, 2_001
    end
  end
end
