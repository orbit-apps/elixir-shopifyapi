defmodule ShopifyAPI.CallLimitTest do
  use ExUnit.Case

  alias ShopifyAPI.CallLimit

  alias HTTPoison.{Error, Response}

  describe "limit_header_or_status_code/1" do
    test "pulls the call_limit header out of response headers" do
      call_limit_header = {"X-Shopify-Shop-Api-Call-Limit", "32/50"}
      response = %Response{headers: [{"foo", "bar"}, call_limit_header, {"bat", "biz"}]}

      assert CallLimit.limit_header_or_status_code(response) == "32/50"
    end

    test "returns :over_limit on status code 429" do
      call_limit_header = {"X-Shopify-Shop-Api-Call-Limit", "32/50"}

      response = %Response{
        status_code: 429,
        headers: [{"foo", "bar"}, call_limit_header, {"bat", "biz"}]
      }

      assert CallLimit.limit_header_or_status_code(response) == :over_limit
    end

    test "returns nil if no call limit header" do
      response = %Response{headers: [{"foo", "bar"}]}

      assert CallLimit.limit_header_or_status_code(response) == nil
    end

    test "returns nil on error" do
      assert CallLimit.limit_header_or_status_code(%Error{}) == nil
    end
  end

  describe "get_api_remaining_calls/1" do
    test "calculates the call limit from the header" do
      header = "32/50"

      assert CallLimit.get_api_remaining_calls(header) == 18
    end

    test "returns 0 for :over_limit" do
      assert CallLimit.get_api_remaining_calls(:over_limit) == 0
    end

    test "nil passes through" do
      assert CallLimit.get_api_remaining_calls(nil) == 0
    end
  end

  describe "get_retry_after_header/1" do
    test "pulls out the value " do
      retry_after_header = {"Retry-After", "1.0"}
      response = %Response{headers: [retry_after_header, {"foo", "bar"}, {"bat", "biz"}]}

      assert CallLimit.get_retry_after_header(response) == "1.0"
    end

    test "defaults to 2.0" do
      response = %Response{headers: [{"foo", "bar"}, {"bat", "biz"}]}

      assert CallLimit.get_retry_after_header(response) == "2.0"
    end
  end

  describe "get_retry_after_milliseconds/1" do
    test "Parses the expected value" do
      assert CallLimit.get_retry_after_milliseconds("2.0") == 2000
    end

    test "parses decimal value" do
      assert CallLimit.get_retry_after_milliseconds("2.3") == 2300
      assert CallLimit.get_retry_after_milliseconds("2.003") == 2003
    end

    test "handles zero leading values" do
      assert CallLimit.get_retry_after_milliseconds("0.2") == 200
    end
  end
end
