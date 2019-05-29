defmodule ShopifyAPI.CallLimitTest do
  use ExUnit.Case

  alias ShopifyAPI.CallLimit

  alias HTTPoison.{Error, Response}

  describe "limit_header_or_status_code/1" do
    test "pulls the call_limit header out of response headers" do
      call_limit_header = {"X-Shopify-Shop-Api-Call-Limit", "32/50"}
      response = %Response{headers: [{"foo", "bar"}, call_limit_header, {"bat", "biz"}]}

      assert CallLimit.limit_header_or_status_code(response) == call_limit_header
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

  describe "get_api_call_limit/1" do
    test "calculates the call limit from the header" do
      header = {"X-Shopify-Shop-Api-Call-Limit", "32/50"}

      assert CallLimit.get_api_call_limit(header) == 18
    end

    test "returns 0 for :over_limit" do
      assert CallLimit.get_api_call_limit(:over_limit) == 0
    end

    test "nil passes through" do
      assert CallLimit.get_api_call_limit(nil) == nil
    end
  end
end
