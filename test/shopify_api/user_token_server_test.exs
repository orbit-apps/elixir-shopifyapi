defmodule ShopifyAPI.UserTokenServerTest do
  use ExUnit.Case, async: true

  # The ETS table is public and shared across the whole suite, so each example keys its tokens
  # on a shop, app and user id that no other example or test uses.
  doctest ShopifyAPI.UserTokenServer
end
