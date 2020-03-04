defmodule Test.ShopifyAPI.ThrottledTest do
  use ExUnit.Case

  alias ShopifyAPI.{AuthToken, RateLimiting, Throttled}

  @token %AuthToken{app_name: "test", shop_name: "throttled", plus: false}

  setup do
    RateLimiting.RESTTracker.set(@token, 10, 0)

    :ok
  end

  def func, do: send(self(), :func_called)
  def sleep_impl(_), do: send(self(), :sleep_called)

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
