defmodule ShopifyAPI.AuthTokenServerTest do
  use ExUnit.Case, async: true

  # The ETS table is public and shared across the whole suite, so each example keys its tokens
  # on a shop and app pair that no other example or test uses. The rest of the suite builds
  # shop names with Faker, so the plain names in the docs cannot collide with them.
  doctest ShopifyAPI.AuthTokenServer
end
