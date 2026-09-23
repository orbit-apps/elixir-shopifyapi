defmodule ShopifyAPI.BulkTest do
  # Not async: shares the public token cache and the global :offline_tokens setting.
  use ExUnit.Case, async: false

  import ShopifyAPI.TokenConfigSetup

  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.AuthTokenServer
  alias ShopifyAPI.Bulk

  @app_name "bulk-test-app"
  @graphql_ver "10"
  @graphql_path "/admin/api/#{@graphql_ver}/graphql.json"
  @query "{ products { edges { node { id } } } }"
  @row %{"id" => "gid://shopify/Product/1"}
  @opts [polling_rate: 1, max_poll_count: 1, auto_cancel: false]

  setup :isolate_token_config

  setup do
    bypass = Bypass.open()
    shop = "localhost:#{bypass.port}"

    Application.put_env(:shopify_api, ShopifyAPI.GraphQL, graphql_version: @graphql_ver)

    token = %AuthToken{shop_name: shop, app_name: @app_name, token: "cached"}
    AuthTokenServer.set(token, false)
    on_exit(fn -> AuthTokenServer.delete(shop, @app_name) end)

    {:ok, bypass: bypass, shop: shop, token: token}
  end

  # Completes every bulk operation at once, with a single result row, and reports the access
  # token each GraphQL request carried to the test process.
  defp complete_bulk_operation(bypass) do
    test_pid = self()
    url = "http://localhost:#{bypass.port}/bulk_response"

    Bypass.expect(bypass, "POST", @graphql_path, fn conn ->
      [access_token] = Plug.Conn.get_req_header(conn, "x-shopify-access-token")
      send(test_pid, {:request, access_token})

      body =
        Jason.encode!(%{
          "data" => %{
            "bulkOperationRunQuery" => %{"userErrors" => [], "bulkOperation" => %{"id" => "1"}},
            "currentBulkOperation" => %{"status" => "COMPLETED", "url" => url},
            "node" => %{"url" => url}
          },
          "extensions" => %{"cost" => %{"throttleStatus" => %{"currentlyAvailable" => 1000}}}
        })

      Plug.Conn.resp(conn, 200, body)
    end)

    Bypass.expect(bypass, "GET", "/bulk_response", fn conn ->
      Plug.Conn.resp(conn, 200, "#{Jason.encode!(@row)}\n")
    end)
  end

  describe "process!" do
    test "takes a myshopify domain and app name", %{bypass: bypass, shop: shop} do
      complete_bulk_operation(bypass)

      assert Bulk.process!(shop, @app_name, @query, @opts) == [@row]
      assert_received {:request, "cached"}
    end

    test "takes a myshopify domain and app name with default options", %{
      bypass: bypass,
      shop: shop
    } do
      complete_bulk_operation(bypass)

      assert Bulk.process!(shop, @app_name, @query) == [@row]
    end

    test "takes an integer polling rate", %{bypass: bypass, shop: shop} do
      complete_bulk_operation(bypass)

      assert Bulk.process!(shop, @app_name, @query, 1) == [@row]
    end

    test "takes a token, sending the one cached for its shop and app", %{
      bypass: bypass,
      token: token
    } do
      complete_bulk_operation(bypass)

      assert Bulk.process!(%{token | token: "stale"}, @query, @opts) == [@row]
      assert_received {:request, "cached"}
      refute_received {:request, "stale"}
    end

    test "takes a token with default options", %{bypass: bypass, token: token} do
      complete_bulk_operation(bypass)

      assert Bulk.process!(token, @query) == [@row]
    end

    test "raises ShopAuthError when no token is cached", %{shop: shop, token: token} do
      AuthTokenServer.delete(shop, @app_name)

      assert_raise ShopifyAPI.ShopAuthError, fn -> Bulk.process!(shop, @app_name, @query) end
      assert_raise ShopifyAPI.ShopAuthError, fn -> Bulk.process!(token, @query) end
    end
  end

  describe "process_stream!" do
    test "takes a myshopify domain and app name", %{bypass: bypass, shop: shop} do
      complete_bulk_operation(bypass)

      assert shop |> Bulk.process_stream!(@app_name, @query, @opts) |> Enum.to_list() == [@row]
      assert_received {:request, "cached"}
    end

    test "takes a myshopify domain and app name with default options", %{
      bypass: bypass,
      shop: shop
    } do
      complete_bulk_operation(bypass)

      assert shop |> Bulk.process_stream!(@app_name, @query) |> Enum.to_list() == [@row]
    end

    test "takes an integer polling rate", %{bypass: bypass, shop: shop} do
      complete_bulk_operation(bypass)

      assert shop |> Bulk.process_stream!(@app_name, @query, 1) |> Enum.to_list() == [@row]
    end

    test "takes a token, sending the one cached for its shop and app", %{
      bypass: bypass,
      token: token
    } do
      complete_bulk_operation(bypass)

      stream = Bulk.process_stream!(%{token | token: "stale"}, @query, @opts)

      assert Enum.to_list(stream) == [@row]
      assert_received {:request, "cached"}
      refute_received {:request, "stale"}
    end

    test "takes a token with default options", %{bypass: bypass, token: token} do
      complete_bulk_operation(bypass)

      assert token |> Bulk.process_stream!(@query) |> Enum.to_list() == [@row]
    end

    test "raises ShopAuthError when no token is cached", %{shop: shop, token: token} do
      AuthTokenServer.delete(shop, @app_name)

      assert_raise ShopifyAPI.ShopAuthError, fn ->
        Bulk.process_stream!(shop, @app_name, @query)
      end

      assert_raise ShopifyAPI.ShopAuthError, fn -> Bulk.process_stream!(token, @query) end
    end
  end

  describe "process_stream_from_id!" do
    test "takes a myshopify domain and app name", %{bypass: bypass, shop: shop} do
      complete_bulk_operation(bypass)

      assert shop |> Bulk.process_stream_from_id!(@app_name, "1") |> Enum.to_list() == [@row]
      assert_received {:request, "cached"}
    end

    test "takes a token, sending the one cached for its shop and app", %{
      bypass: bypass,
      token: token
    } do
      complete_bulk_operation(bypass)

      stream = Bulk.process_stream_from_id!(%{token | token: "stale"}, "1")

      assert Enum.to_list(stream) == [@row]
      assert_received {:request, "cached"}
      refute_received {:request, "stale"}
    end

    test "raises ShopAuthError when no token is cached", %{shop: shop, token: token} do
      AuthTokenServer.delete(shop, @app_name)

      assert_raise ShopifyAPI.ShopAuthError, fn ->
        Bulk.process_stream_from_id!(shop, @app_name, "1")
      end

      assert_raise ShopifyAPI.ShopAuthError, fn -> Bulk.process_stream_from_id!(token, "1") end
    end
  end
end
