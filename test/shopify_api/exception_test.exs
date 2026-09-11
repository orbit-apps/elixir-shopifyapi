defmodule ShopifyAPI.ExceptionTest do
  use ExUnit.Case, async: true

  describe "Plug status" do
    test "a failed refresh renders as 503, since it is assumed to be transient" do
      assert Plug.Exception.status(%ShopifyAPI.TokenRefreshError{}) == 503
    end

    test "a failed write renders as 500, since it is the app's own fault" do
      assert Plug.Exception.status(%ShopifyAPI.TokenPersistenceError{}) == 500
    end
  end
end
