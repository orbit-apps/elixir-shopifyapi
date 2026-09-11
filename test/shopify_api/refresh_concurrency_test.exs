defmodule ShopifyAPI.RefreshConcurrencyTest do
  @moduledoc """
  De-duplication, waiting and retry behaviour of `ShopifyAPI.Refresh`.

  Tests drive real tasks against a Bypass server that holds its response open, so
  interleaving is controlled by messages rather than by timing.
  """

  # Not async: shares the registry, the token cache, and the :refresh_retry setting.
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Plug.Conn
  alias ShopifyAPI.App
  alias ShopifyAPI.AppServer
  alias ShopifyAPI.AuthTokenServer
  alias ShopifyAPI.JSONSerializer
  alias ShopifyAPI.Refresh

  @app_name "refresh-concurrency-app"

  setup do
    # A client id of its own: the app cache is shared across the suite and
    # `AppServer.get_by_client_id/1` only resolves when exactly one app matches.
    AppServer.set(%App{
      name: @app_name,
      client_id: "concurrency-client-id",
      client_secret: "client-secret"
    })

    previous_retry = Application.get_env(:shopify_api, :refresh_retry)

    on_exit(fn ->
      if previous_retry do
        Application.put_env(:shopify_api, :refresh_retry, previous_retry)
      else
        Application.delete_env(:shopify_api, :refresh_retry)
      end
    end)

    bypass = Bypass.open()
    {:ok, bypass: bypass, shop: "localhost:#{bypass.port}"}
  end

  defp cache(shop, attrs \\ []) do
    token =
      ShopifyAPI.Test.expired_token(
        [shop_name: shop, app_name: @app_name, token: "shpat_current"] ++ attrs
      )

    AuthTokenServer.set(token, false)
    token
  end

  defp pair_json do
    JSONSerializer.encode!(%{
      access_token: "shpat_refreshed",
      expires_in: 3600,
      refresh_token: "shprt_refreshed",
      refresh_token_expires_in: 7_775_999
    })
  end

  # A handler that announces itself and then blocks until the test releases it, so a refresh can
  # be held in flight for as long as the test needs.
  defp held_open(bypass) do
    test_pid = self()

    Bypass.expect(bypass, "POST", "/admin/oauth/access_token", fn conn ->
      send(test_pid, {:refresh_started, self()})

      receive do
        :release -> Conn.resp(conn, 200, pair_json())
      after
        5_000 -> Conn.resp(conn, 500, "test never released the handler")
      end
    end)
  end

  # Lets a held request finish, then waits for the background task that made it to exit. The
  # cache is no signal of that: the task writes the new pair before it returns, and holds its
  # registry key until it exits.
  defp release(handler, shop) do
    [{task, :refreshing}] = Registry.lookup(ShopifyAPI.RefreshRegistry, {shop, @app_name})
    ref = Process.monitor(task)
    send(handler, :release)
    assert_receive {:DOWN, ^ref, :process, ^task, :normal}, 2_000
  end

  defp await_cached(shop, expected, attempts \\ 100) do
    case AuthTokenServer.get(shop, @app_name) do
      {:ok, %{token: ^expected}} ->
        :ok

      _ when attempts > 0 ->
        Process.sleep(20)
        await_cached(shop, expected, attempts - 1)

      _ ->
        :timeout
    end
  end

  describe "background de-duplication" do
    test "a second background refresh is not started while one is in flight", %{
      bypass: bypass,
      shop: shop
    } do
      held_open(bypass)
      token = cache(shop)

      Refresh.run_in_background(token)
      # The request is under way, so the task has already claimed the registry.
      assert_receive {:refresh_started, handler}, 2_000

      Refresh.run_in_background(token)
      refute_receive {:refresh_started, _}, 300

      release(handler, shop)
    end

    test "a refresh can be started again once the previous one has finished", %{
      bypass: bypass,
      shop: shop
    } do
      # The registry entry is held by the task, so it goes away when the task does.
      held_open(bypass)
      token = cache(shop)

      Refresh.run_in_background(token)
      assert_receive {:refresh_started, first}, 2_000
      release(first, shop)

      Refresh.run_in_background(cache(shop))
      assert_receive {:refresh_started, second}, 2_000
      release(second, shop)
    end
  end

  describe "awaiting a refresh in flight" do
    test "waits for the running refresh rather than starting its own", %{
      bypass: bypass,
      shop: shop
    } do
      held_open(bypass)
      token = cache(shop)

      Refresh.run_in_background(token)
      assert_receive {:refresh_started, handler}, 2_000

      # Release shortly, so await_or_run/1 genuinely blocks before the result arrives.
      spawn(fn ->
        Process.sleep(100)
        send(handler, :release)
      end)

      assert {:ok, refreshed} = Refresh.await_or_run(token)
      assert refreshed.token == "shpat_refreshed"

      # One HTTP call served both the task and the waiter.
      refute_receive {:refresh_started, _}, 300
    end

    test "refreshes itself when the wait times out", %{bypass: bypass, shop: shop} do
      Application.put_env(:shopify_api, :refresh_wait_timeout_ms, 50)
      on_exit(fn -> Application.delete_env(:shopify_api, :refresh_wait_timeout_ms) end)

      test_pid = self()
      counter = :counters.new(1, [])

      Bypass.expect(bypass, "POST", "/admin/oauth/access_token", fn conn ->
        :counters.add(counter, 1, 1)
        send(test_pid, {:refresh_started, self()})

        # Hold the first request open past the waiter's timeout; answer the rest at once.
        if :counters.get(counter, 1) == 1 do
          receive do
            :release -> :ok
          after
            5_000 -> :ok
          end
        end

        Conn.resp(conn, 200, pair_json())
      end)

      token = cache(shop)
      Refresh.run_in_background(token)
      assert_receive {:refresh_started, first}, 2_000

      assert {:ok, refreshed} = Refresh.await_or_run(token)
      assert refreshed.token == "shpat_refreshed"
      assert :counters.get(counter, 1) == 2

      # Let the held request finish, so no task outlives the Bypass server.
      release(first, shop)
    end
  end

  describe "retry and backoff" do
    test "retries a transient failure and succeeds", %{bypass: bypass, shop: shop} do
      Application.put_env(:shopify_api, :refresh_retry, attempts: 3, backoff_ms: 1)

      counter = :counters.new(1, [])

      Bypass.expect(bypass, "POST", "/admin/oauth/access_token", fn conn ->
        :counters.add(counter, 1, 1)

        case :counters.get(counter, 1) do
          1 -> Conn.resp(conn, 503, "")
          _ -> Conn.resp(conn, 200, pair_json())
        end
      end)

      capture_log(fn ->
        Refresh.run_in_background(cache(shop))
        assert :ok = await_cached(shop, "shpat_refreshed")
      end)

      assert :counters.get(counter, 1) == 2
    end

    test "gives up after the configured attempts and leaves the token alone", %{
      bypass: bypass,
      shop: shop
    } do
      Application.put_env(:shopify_api, :refresh_retry, attempts: 2, backoff_ms: 1)

      counter = :counters.new(1, [])

      Bypass.expect(bypass, "POST", "/admin/oauth/access_token", fn conn ->
        :counters.add(counter, 1, 1)
        Conn.resp(conn, 503, "")
      end)

      original = cache(shop)

      log =
        capture_log(fn ->
          Refresh.run_in_background(original)
          # Long enough for both attempts and the backoff between them.
          Process.sleep(400)
        end)

      assert :counters.get(counter, 1) == 2
      assert log =~ "gave up refreshing"
      assert {:ok, ^original} = AuthTokenServer.get(shop, @app_name)
    end

    test "does not retry a token naming an app that is not registered", %{shop: shop} do
      Application.put_env(:shopify_api, :refresh_retry, attempts: 3, backoff_ms: 1)

      token = ShopifyAPI.Test.expired_token(shop_name: shop, app_name: "never-registered")

      log =
        capture_log(fn ->
          Refresh.run_in_background(token)
          Process.sleep(200)
        end)

      # A config error, not a blip: it should surface immediately rather than after backoff.
      refute log =~ "gave up refreshing"
      assert log =~ "not a registered app"
    end
  end
end
