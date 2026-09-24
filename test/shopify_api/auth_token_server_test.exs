defmodule ShopifyAPI.AuthTokenServerTest do
  # Not async: the persistence tests swap the callback in application env, which is global.
  use ExUnit.Case, async: false

  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.AuthTokenServer
  alias ShopifyAPI.TokenPersistenceError

  # The ETS table is public and shared across the whole suite, so each example keys its tokens
  # on a shop and app pair that no other example or test uses. The rest of the suite builds
  # shop names with Faker, so the plain names in the docs cannot collide with them.
  doctest ShopifyAPI.AuthTokenServer

  defmodule PersistenceDouble do
    @moduledoc false

    alias ShopifyAPI.AuthToken

    def save(_key, %AuthToken{shop_name: "raising.myshopify.com"}),
      do: raise(ArgumentError, "storage is down")

    def save(_key, %AuthToken{shop_name: "erroring.myshopify.com"}), do: {:error, :db_unavailable}
    def save(_key, %AuthToken{shop_name: "nil-returning.myshopify.com"}), do: nil

    # Shaped like an `{:error, changeset}`, whose changes carry the token being written.
    def save(_key, %AuthToken{shop_name: "rejecting.myshopify.com"} = token),
      do: {:error, %{changes: %{token: token.token}}}

    # The callback runs in the calling process, so this reaches the test.
    def save(key, token) do
      send(self(), {:persisted, key, token})
      :ok
    end
  end

  setup do
    previous = Application.get_env(:shopify_api, AuthTokenServer)

    Application.put_env(:shopify_api, AuthTokenServer,
      persistence: {PersistenceDouble, :save, []}
    )

    on_exit(fn ->
      if previous do
        Application.put_env(:shopify_api, AuthTokenServer, previous)
      else
        Application.delete_env(:shopify_api, AuthTokenServer)
      end
    end)

    :ok
  end

  defp token(shop_name, attrs \\ []) do
    struct!(
      %AuthToken{shop_name: shop_name, app_name: "persistence-test-app", token: "shpat_abc"},
      attrs
    )
  end

  defmodule LoadDouble do
    @moduledoc false

    alias ShopifyAPI.AuthToken

    def get("raising.myshopify.com", _app_name), do: raise(ArgumentError, "storage is down")
    def get("absent.myshopify.com", _app_name), do: {:error, :not_found}

    def get(shop_name, app_name) do
      send(self(), {:loaded, shop_name, app_name})
      {:ok, %AuthToken{shop_name: shop_name, app_name: app_name, token: "shpat_stored"}}
    end

    def get_with_arg(shop_name, app_name, tag) do
      send(self(), {:loaded, shop_name, app_name, tag})
      {:ok, %AuthToken{shop_name: shop_name, app_name: app_name, token: "shpat_stored"}}
    end
  end

  defp persistence(callbacks),
    do: Application.put_env(:shopify_api, AuthTokenServer, persistence: callbacks)

  describe "persistence configuration" do
    test "bare tuple works as the save callback" do
      persistence({PersistenceDouble, :save, []})

      assert :ok = AuthTokenServer.set(token("bare-mfa.myshopify.com"))
      assert_received {:persisted, "bare-mfa.myshopify.com:persistence-test-app", _}
    end

    test "bare 2-tuple works as the save callback" do
      persistence({PersistenceDouble, :save})

      assert :ok = AuthTokenServer.set(token("bare-mf.myshopify.com"))
      assert_received {:persisted, "bare-mf.myshopify.com:persistence-test-app", _}
    end

    test "bare tuple is not used as the load callback" do
      persistence({LoadDouble, :get, []})

      assert {:error, :not_found} = AuthTokenServer.reload("bare-get.myshopify.com", "any-app")
      refute_received {:loaded, _, _}
    end

    test "keyword list uses save callback" do
      persistence(save: {PersistenceDouble, :save, []})

      assert :ok = AuthTokenServer.set(token("keyword-save.myshopify.com"))
      assert_received {:persisted, "keyword-save.myshopify.com:persistence-test-app", _}
    end

    test "keyword list uses load callback" do
      persistence(load: {LoadDouble, :get})

      assert {:ok, %AuthToken{token: "shpat_stored"}} =
               AuthTokenServer.reload("keyword-load.myshopify.com", "persistence-test-app")

      assert_received {:loaded, "keyword-load.myshopify.com", "persistence-test-app"}
    end

    test "nil persistence disables both callbacks" do
      persistence(nil)

      assert :ok = AuthTokenServer.set(token("unconfigured.myshopify.com"))
      refute_received {:persisted, _, _}
    end
  end

  describe "reload/2 without a load callback" do
    test "returns the cached token" do
      token = token("reload-cached.myshopify.com")
      AuthTokenServer.set(token, false)

      assert {:ok, ^token} =
               AuthTokenServer.reload("reload-cached.myshopify.com", "persistence-test-app")
    end

    test "returns not found when nothing is cached" do
      assert {:error, :not_found} =
               AuthTokenServer.reload("reload-uncached.myshopify.com", "persistence-test-app")
    end
  end

  describe "reload/2 with a load callback" do
    setup do
      persistence(load: {LoadDouble, :get}, save: {PersistenceDouble, :save})
      :ok
    end

    test "returns the stored token and caches it without persisting" do
      AuthTokenServer.set(token("stored.myshopify.com", token: "shpat_cached"), false)

      assert {:ok, %AuthToken{token: "shpat_stored"}} =
               AuthTokenServer.reload("stored.myshopify.com", "persistence-test-app")

      assert {:ok, %AuthToken{token: "shpat_stored"}} =
               AuthTokenServer.get("stored.myshopify.com", "persistence-test-app")

      refute_received {:persisted, _, _}
    end

    test "caches the stored token when nothing was cached" do
      assert {:ok, %AuthToken{token: "shpat_stored"}} =
               AuthTokenServer.reload("fresh.myshopify.com", "persistence-test-app")

      assert {:ok, %AuthToken{token: "shpat_stored"}} =
               AuthTokenServer.get("fresh.myshopify.com", "persistence-test-app")
    end

    test "appends configured arguments to the callback" do
      persistence(load: {LoadDouble, :get_with_arg, [:tagged]})

      AuthTokenServer.reload("args.myshopify.com", "persistence-test-app")
      assert_received {:loaded, "args.myshopify.com", "persistence-test-app", :tagged}
    end

    test "returns not found when storage has no token" do
      assert {:error, :not_found} =
               AuthTokenServer.reload("absent.myshopify.com", "persistence-test-app")
    end

    test "lets an exception from the callback propagate" do
      assert_raise ArgumentError, "storage is down", fn ->
        AuthTokenServer.reload("raising.myshopify.com", "persistence-test-app")
      end
    end
  end

  describe "set/2 persistence" do
    test "calls the callback with the string key and the token" do
      token = token("persists.myshopify.com")

      assert :ok = AuthTokenServer.set(token)
      assert_received {:persisted, "persists.myshopify.com:persistence-test-app", ^token}
    end

    test "skips the callback when told not to persist" do
      assert :ok = AuthTokenServer.set(token("unpersisted.myshopify.com"), false)
      refute_received {:persisted, _, _}
    end

    test "treats a nil return as success" do
      assert :ok = AuthTokenServer.set(token("nil-returning.myshopify.com"))
      assert {:ok, _} = AuthTokenServer.get("nil-returning.myshopify.com", "persistence-test-app")
    end

    test "raises when the callback returns an error tuple" do
      assert_raise TokenPersistenceError, ~r/db_unavailable/, fn ->
        AuthTokenServer.set(token("erroring.myshopify.com"))
      end
    end

    test "keeps the error reason's contents out of the message" do
      error =
        assert_raise TokenPersistenceError, fn ->
          AuthTokenServer.set(token("rejecting.myshopify.com"))
        end

      refute error.message =~ "shpat_abc"
    end

    test "lets an exception from the callback propagate" do
      assert_raise ArgumentError, "storage is down", fn ->
        AuthTokenServer.set(token("raising.myshopify.com"))
      end
    end
  end

  describe "set/2 write ordering" do
    # A failed persist must not update the cache — both sides stay on the old pair.
    test "leaves the cached token untouched when persistence errors" do
      original = token("erroring.myshopify.com", refresh_token: "shprt_original")
      AuthTokenServer.set(original, false)

      assert_raise TokenPersistenceError, fn ->
        AuthTokenServer.set(token("erroring.myshopify.com", refresh_token: "shprt_replacement"))
      end

      assert {:ok, ^original} =
               AuthTokenServer.get("erroring.myshopify.com", "persistence-test-app")
    end

    test "leaves the cached token untouched when the callback raises" do
      original = token("raising.myshopify.com", refresh_token: "shprt_original")
      AuthTokenServer.set(original, false)

      assert_raise ArgumentError, fn ->
        AuthTokenServer.set(token("raising.myshopify.com", refresh_token: "shprt_replacement"))
      end

      assert {:ok, ^original} =
               AuthTokenServer.get("raising.myshopify.com", "persistence-test-app")
    end
  end
end
