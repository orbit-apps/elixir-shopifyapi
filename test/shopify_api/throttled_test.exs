defmodule Test.ShopifyAPI.ThrottledTest do
  use ExUnit.Case

  alias ShopifyAPI.{AuthToken, ThrottleServer, Throttled}

  @token %AuthToken{app_name: "test", shop_name: "throttled", plus: false}

  setup do
    ThrottleServer.set(10, @token)

    :ok
  end

  def func, do: send(self(), :func_called)
  def sleep_impl(_), do: send(self(), :sleep_called)

  describe "make_request/4" do
    test "if no time set call right away" do
      Throttled.make_request({1, :no_time}, &func/0, 2, &sleep_impl/1)
      assert_receive :func_called
    end

    test "if limit has room call right away" do
      Throttled.make_request({1, NaiveDateTime.utc_now()}, &func/0, 2, &sleep_impl/1)
      assert_receive :func_called
    end

    test "does not sleep if there limit set 0 and time was a bit ago" do
      last_call = NaiveDateTime.add(NaiveDateTime.utc_now(), -1)
      Throttled.make_request({0, last_call}, &func/0, 2, &sleep_impl/1)
      refute_receive :sleep_called
    end

    test "sleeps if there limit set 0 and time was recent" do
      Throttled.make_request({0, NaiveDateTime.utc_now()}, &func/0, 2, &sleep_impl/1)
      assert_receive :sleep_called, 2_000
    end
  end
end
