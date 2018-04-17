defmodule Plug.ShopifyApiTest do
  use ExUnit.Case
  doctest Plug.ShopifyApi

  test "greets the world" do
    assert Plug.ShopifyApi.hello() == :world
  end
end
