defmodule ShopifyAPI.ConfigTest do
  # Not async: swaps the top-level :offline_tokens and :expiring settings, which are global.
  use ExUnit.Case, async: false

  import ShopifyAPI.TokenConfigSetup

  alias ShopifyAPI.Config

  setup :isolate_token_config

  describe "offline_tokens/0" do
    test "defaults to :permanent" do
      assert Config.offline_tokens() == :permanent
    end

    test "returns each valid :offline_tokens setting" do
      for mode <- [:permanent, :expiring, :exchange_permanent] do
        Application.put_env(:shopify_api, :offline_tokens, mode)
        assert Config.offline_tokens() == mode
      end
    end

    test "maps expiring: true to :expiring" do
      Application.put_env(:shopify_api, :expiring, true)
      assert Config.offline_tokens() == :expiring
    end

    test "maps expiring: false to :permanent" do
      Application.put_env(:shopify_api, :expiring, false)
      assert Config.offline_tokens() == :permanent
    end

    test "treats a non-boolean :expiring as :permanent" do
      Application.put_env(:shopify_api, :expiring, "true")
      assert Config.offline_tokens() == :permanent
    end

    test "prefers :offline_tokens over :expiring" do
      Application.put_env(:shopify_api, :expiring, true)
      Application.put_env(:shopify_api, :offline_tokens, :permanent)
      assert Config.offline_tokens() == :permanent
    end

    test "raises on an unknown :offline_tokens setting, naming the valid ones" do
      Application.put_env(:shopify_api, :offline_tokens, :migrate)

      assert_raise ArgumentError, ~r/:migrate.*:permanent, :expiring, :exchange_permanent/, fn ->
        Config.offline_tokens()
      end
    end

    test "treats an explicit nil :offline_tokens as unset" do
      Application.put_env(:shopify_api, :expiring, true)
      Application.put_env(:shopify_api, :offline_tokens, nil)

      assert Config.offline_tokens() == :expiring
    end
  end

  describe "expiring?/0" do
    test "is false only for :permanent" do
      for {mode, expected} <- [permanent: false, expiring: true, exchange_permanent: true] do
        Application.put_env(:shopify_api, :offline_tokens, mode)
        assert Config.expiring?() == expected
      end
    end

    test "follows the legacy :expiring setting" do
      Application.put_env(:shopify_api, :expiring, true)
      assert Config.expiring?()
    end
  end
end
