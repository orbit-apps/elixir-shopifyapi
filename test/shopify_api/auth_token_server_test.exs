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

  # Storage for the `get` callback, keyed on shop name. Its `set` reports what it is handed.
  defmodule StorageDouble do
    @moduledoc false

    alias ShopifyAPI.AuthToken

    def get(shop_name, app_name, tag \\ :no_args)

    def get("raising.myshopify.com", _app_name, _tag), do: raise(ArgumentError, "storage is down")
    def get("absent.myshopify.com", _app_name, _tag), do: {:error, :not_found}

    # Shaped like an `{:error, changeset}`, whose changes carry a token.
    def get("rejecting.myshopify.com", _app_name, _tag),
      do: {:error, %{changes: %{token: "shpat_secret"}}}

    def get("unwrapped.myshopify.com" = shop_name, app_name, _tag),
      do: %AuthToken{shop_name: shop_name, app_name: app_name, token: "shpat_secret"}

    # Another process caches a newer token while storage is being read.
    def get("raced" <> _ = shop_name, app_name, _tag) do
      ShopifyAPI.AuthTokenServer.set(
        %AuthToken{shop_name: shop_name, app_name: app_name, token: "shpat_newer"},
        false
      )

      {:ok, %AuthToken{shop_name: shop_name, app_name: app_name, token: "shpat_stored"}}
    end

    def get("misfiled.myshopify.com", app_name, _tag),
      do:
        {:ok,
         %AuthToken{shop_name: "other.myshopify.com", app_name: app_name, token: "shpat_secret"}}

    def get(shop_name, app_name, tag) do
      send(self(), {:loaded, shop_name, app_name, tag})
      {:ok, %AuthToken{shop_name: shop_name, app_name: app_name, token: "shpat_stored"}}
    end

    def set(key, token) do
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

  defp persistence(callbacks),
    do: Application.put_env(:shopify_api, AuthTokenServer, persistence: callbacks)

  defp cached(shop_name), do: AuthTokenServer.get(shop_name, "persistence-test-app")

  describe "persistence configuration" do
    test "takes a bare {module, function, args} tuple as the set callback" do
      persistence({StorageDouble, :set, []})

      assert :ok = AuthTokenServer.set(token("bare-mfa.myshopify.com"))
      assert_received {:persisted, "bare-mfa.myshopify.com:persistence-test-app", _}
    end

    test "takes a bare {module, function} tuple as the set callback" do
      persistence({StorageDouble, :set})

      assert :ok = AuthTokenServer.set(token("bare-mf.myshopify.com"))
      assert_received {:persisted, "bare-mf.myshopify.com:persistence-test-app", _}
    end

    test "does not take a bare tuple as the get callback" do
      persistence({StorageDouble, :get, []})

      assert {:error, :not_found} = AuthTokenServer.reload("bare-get.myshopify.com", "any-app")
      refute_received {:loaded, _, _, _}
    end

    test "takes set from the keyword list, in either tuple form" do
      persistence(set: {StorageDouble, :set, []})
      assert :ok = AuthTokenServer.set(token("keyword-mfa.myshopify.com"))
      assert_received {:persisted, "keyword-mfa.myshopify.com:persistence-test-app", _}

      persistence(set: {StorageDouble, :set})
      assert :ok = AuthTokenServer.set(token("keyword-mf.myshopify.com"))
      assert_received {:persisted, "keyword-mf.myshopify.com:persistence-test-app", _}
    end

    test "writes to the cache alone when only get is configured" do
      persistence(get: {StorageDouble, :get, []})

      assert :ok = AuthTokenServer.set(token("get-only.myshopify.com"))
      refute_received {:persisted, _, _}
      assert {:ok, _} = cached("get-only.myshopify.com")
    end

    test "calls neither callback when persistence is nil" do
      persistence(nil)

      assert :ok = AuthTokenServer.set(token("unconfigured.myshopify.com"))

      assert {:ok, _} =
               AuthTokenServer.reload("unconfigured.myshopify.com", "persistence-test-app")

      refute_received {:persisted, _, _}
      refute_received {:loaded, _, _, _}
    end
  end

  describe "reload/2 without a get callback" do
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

  describe "reload/2 with a get callback" do
    setup do
      persistence(get: {StorageDouble, :get, []}, set: {StorageDouble, :set, []})
    end

    test "returns the stored token and caches it without writing it back" do
      AuthTokenServer.set(token("stored.myshopify.com", token: "shpat_cached"), false)

      assert {:ok, %AuthToken{token: "shpat_stored"} = stored} =
               AuthTokenServer.reload("stored.myshopify.com", "persistence-test-app")

      assert {:ok, ^stored} = cached("stored.myshopify.com")
      refute_received {:persisted, _, _}
    end

    test "caches the stored token when nothing was cached" do
      assert {:ok, stored} =
               AuthTokenServer.reload("stored-only.myshopify.com", "persistence-test-app")

      assert {:ok, ^stored} = cached("stored-only.myshopify.com")
    end

    test "calls the callback with the shop and app names and appends configured arguments" do
      persistence(get: {StorageDouble, :get, [:tagged]})
      AuthTokenServer.reload("args.myshopify.com", "persistence-test-app")
      assert_received {:loaded, "args.myshopify.com", "persistence-test-app", :tagged}

      persistence(get: {StorageDouble, :get})
      AuthTokenServer.reload("no-args.myshopify.com", "persistence-test-app")
      assert_received {:loaded, "no-args.myshopify.com", "persistence-test-app", :no_args}
    end

    test "returns the cached token, untouched, when storage has none" do
      token = token("absent.myshopify.com")
      AuthTokenServer.set(token, false)

      assert {:ok, ^token} =
               AuthTokenServer.reload("absent.myshopify.com", "persistence-test-app")

      assert {:ok, ^token} = cached("absent.myshopify.com")
    end

    test "returns not found when neither storage nor the cache has a token" do
      assert {:error, :not_found} =
               AuthTokenServer.reload("absent.myshopify.com", "reload-uncached-app")
    end

    test "keeps a token cached while storage was being read over the stored one" do
      AuthTokenServer.set(token("raced.myshopify.com", token: "shpat_original"), false)

      assert {:ok, %AuthToken{token: "shpat_newer"}} =
               AuthTokenServer.reload("raced.myshopify.com", "persistence-test-app")

      assert {:ok, %AuthToken{token: "shpat_newer"}} = cached("raced.myshopify.com")
    end

    test "keeps a token first cached while storage was being read over the stored one" do
      assert {:ok, %AuthToken{token: "shpat_newer"}} =
               AuthTokenServer.reload("raced-uncached.myshopify.com", "persistence-test-app")

      assert {:ok, %AuthToken{token: "shpat_newer"}} = cached("raced-uncached.myshopify.com")
    end

    test "raises on an error tuple, keeping the reason's contents out of the message" do
      token = token("rejecting.myshopify.com")
      AuthTokenServer.set(token, false)

      error =
        assert_raise TokenPersistenceError, ~r/rejecting.myshopify.com/, fn ->
          AuthTokenServer.reload("rejecting.myshopify.com", "persistence-test-app")
        end

      refute error.message =~ "shpat_secret"
      assert {:ok, ^token} = cached("rejecting.myshopify.com")
    end

    test "raises on a token that is not wrapped in an ok tuple, without quoting it" do
      error =
        assert_raise TokenPersistenceError, fn ->
          AuthTokenServer.reload("unwrapped.myshopify.com", "persistence-test-app")
        end

      refute error.message =~ "shpat_secret"
      assert {:error, :not_found} = cached("unwrapped.myshopify.com")
    end

    test "raises on a token for a different shop, without caching it" do
      error =
        assert_raise TokenPersistenceError, fn ->
          AuthTokenServer.reload("misfiled.myshopify.com", "persistence-test-app")
        end

      refute error.message =~ "shpat_secret"
      assert {:error, :not_found} = cached("other.myshopify.com")
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
