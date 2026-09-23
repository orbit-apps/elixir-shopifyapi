defmodule ShopifyAPI.Bulk.QueryTest do
  # Not async: shares the public token cache and the global :offline_tokens setting.
  use ExUnit.Case, async: false

  import ShopifyAPI.TokenConfigSetup

  alias ShopifyAPI.AuthTokenServer
  alias ShopifyAPI.Bulk.Query

  @valid_graphql_response %{
    "data" => %{
      "bulkOperationRunQuery" => %{"userErrors" => [], "bulkOperation" => %{"id" => "1"}},
      "currentBulkOperation" => %{"status" => "COMPLETED", "url" => "here_stuff"}
    },
    "extensions" => %{"cost" => %{"throttleStatus" => %{"currentlyAvailable" => 1000}}}
  }
  @valid_jsonl_response %{val: :foo}
  @graphql_ver "10"
  @graphql_path "/admin/api/#{@graphql_ver}/graphql.json"
  @app_name "bulk-query-test-app"

  setup :isolate_token_config

  setup _context do
    bypass = Bypass.open()

    Application.put_env(:shopify_api, ShopifyAPI.GraphQL, graphql_version: @graphql_ver)

    token = %ShopifyAPI.AuthToken{
      token: "token",
      shop_name: "localhost:#{bypass.port}",
      app_name: @app_name
    }

    AuthTokenServer.set(token, false)
    on_exit(fn -> AuthTokenServer.delete(token.shop_name, token.app_name) end)

    shop = %ShopifyAPI.Shop{domain: "localhost:#{bypass.port}"}

    opts = [polling_rate: 1, max_poll_count: 1, auto_cancel: false]

    {:ok,
     %{
       shop: shop,
       auth_token: token,
       bypass: bypass,
       options: opts,
       url: "localhost:#{bypass.port}/"
     }}
  end

  test "happy path", %{bypass: bypass, shop: _shop, auth_token: token, options: options} do
    Bypass.expect(bypass, "POST", @graphql_path, fn conn ->
      body =
        @valid_graphql_response
        |> put_in(
          ["data", "currentBulkOperation", "url"],
          "localhost:#{bypass.port}/bulk_response"
        )
        |> Jason.encode!()

      Plug.Conn.resp(conn, 200, body)
    end)

    Bypass.expect(bypass, "GET", "/bulk_response", fn conn ->
      Plug.Conn.resp(conn, 200, "#{Jason.encode!(@valid_jsonl_response)}\n")
    end)

    assert url = Query.exec!(token, "fake_query", options)
    assert {:ok, _} = Query.fetch(url, token)
  end

  test "polling timeout", %{bypass: bypass, shop: _shop, auth_token: token, options: options} do
    Bypass.expect(bypass, "POST", @graphql_path, fn conn ->
      body =
        @valid_graphql_response
        |> put_in(
          ["data", "currentBulkOperation", "status"],
          "INCOMPLETE"
        )
        |> Jason.encode!()

      Plug.Conn.resp(conn, 200, body)
    end)

    assert_raise ShopifyAPI.Bulk.TimeoutError, fn ->
      Query.exec!(token, "fake_query", options)
    end
  end

  test "invalid graphql", %{bypass: bypass, shop: _shop, auth_token: token, options: options} do
    Bypass.expect(bypass, "POST", @graphql_path, fn conn ->
      body =
        @valid_graphql_response
        |> put_in(
          ["data", "bulkOperationRunQuery", "userErrors"],
          [
            %{"field" => ["query"], "message" => "Bulk query is not valid GraphQL"}
          ]
        )
        |> Jason.encode!()

      Plug.Conn.resp(conn, 200, body)
    end)

    assert_raise ShopifyAPI.Bulk.QueryError, fn ->
      Query.exec!(token, "fake_query", options)
    end
  end

  test "bulk op already in progress", %{
    bypass: bypass,
    shop: _shop,
    auth_token: token,
    options: options
  } do
    Bypass.expect(bypass, "POST", @graphql_path, fn conn ->
      body =
        @valid_graphql_response
        |> put_in(
          ["data", "bulkOperationRunQuery", "userErrors"],
          [
            %{
              "field" => nil,
              "message" =>
                "A bulk query operation for this app and shop is already in progress: gid://fake-bulk-op-id"
            }
          ]
        )
        |> Jason.encode!()

      Plug.Conn.resp(conn, 200, body)
    end)

    assert_raise ShopifyAPI.Bulk.InProgressError, fn ->
      Query.exec!(token, "fake_query", options)
    end
  end

  test "exec/1 with 404 response", %{
    bypass: bypass,
    shop: _shop,
    auth_token: token,
    options: options
  } do
    Bypass.expect(bypass, "POST", @graphql_path, fn conn ->
      Plug.Conn.resp(conn, 404, Jason.encode!(""))
    end)

    assert_raise ShopifyAPI.ShopNotFoundError, fn ->
      Query.exec!(token, "fake_query", options)
    end
  end

  test "exec/1 with 423 response", %{
    bypass: bypass,
    shop: _shop,
    auth_token: token,
    options: options
  } do
    Bypass.expect(bypass, "POST", @graphql_path, fn conn ->
      Plug.Conn.resp(conn, 423, Jason.encode!(""))
    end)

    assert_raise ShopifyAPI.ShopUnavailableError, fn ->
      Query.exec!(token, "fake_query", options)
    end
  end

  describe "token resolution" do
    # Answers the GraphQL requests with `statuses` in turn, reporting the access token each one
    # carried to the test process. The cached token is refreshed while answering the first poll,
    # the second request.
    defp refresh_during_first_poll(bypass, token, statuses) do
      test_pid = self()
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      Bypass.expect(bypass, "POST", @graphql_path, fn conn ->
        [access_token] = Plug.Conn.get_req_header(conn, "x-shopify-access-token")
        send(test_pid, {:request, access_token})
        index = Agent.get_and_update(counter, &{&1, &1 + 1})
        if index == 1, do: AuthTokenServer.set(%{token | token: "refreshed"}, false)

        body =
          @valid_graphql_response
          |> put_in(["data", "currentBulkOperation", "status"], Enum.at(statuses, index))
          |> put_in(
            ["data", "bulkOperationCancel"],
            %{"bulkOperation" => %{"status" => "CANCELED"}, "userErrors" => []}
          )
          |> Jason.encode!()

        Plug.Conn.resp(conn, 200, body)
      end)
    end

    defp sent_tokens do
      receive do
        {:request, access_token} -> [access_token | sent_tokens()]
      after
        0 -> []
      end
    end

    test "polling sends the token cached at the time of each request", %{
      bypass: bypass,
      auth_token: token,
      options: options
    } do
      refresh_during_first_poll(bypass, token, ["CREATED", "RUNNING", "COMPLETED"])
      options = Keyword.put(options, :max_poll_count, 2)

      assert "here_stuff" = Query.exec!(token, "fake_query", options)
      assert sent_tokens() == ["token", "token", "refreshed"]
    end

    test "auto-cancel sends the token cached at the time of each request", %{
      bypass: bypass,
      auth_token: token,
      options: options
    } do
      refresh_during_first_poll(bypass, token, ["CREATED", "RUNNING"])
      options = Keyword.put(options, :auto_cancel, true)

      assert_raise ShopifyAPI.Bulk.TimeoutError, fn ->
        Query.exec!(token, "fake_query", options)
      end

      assert sent_tokens() == ["token", "token", "refreshed"]
    end

    test "raises ShopAuthError when no token is cached", %{auth_token: token, options: options} do
      AuthTokenServer.delete(token.shop_name, token.app_name)

      assert_raise ShopifyAPI.ShopAuthError, ~r/not_found/, fn ->
        Query.exec!(token, "fake_query", options)
      end
    end

    test "raises ShopAuthError when the cached token needs reacquisition", %{
      auth_token: token,
      options: options
    } do
      [shop_name: token.shop_name, app_name: token.app_name]
      |> ShopifyAPI.Test.dead_token()
      |> AuthTokenServer.set(false)

      assert_raise ShopifyAPI.ShopAuthError, ~r/needs_reacquisition/, fn ->
        Query.exec!(token, "fake_query", options)
      end
    end
  end

  @json1 %{"test" => "foo"}
  @json2 %{"test" => "bar fuzz"}
  @json3 %{"test" => "baz\nbuzz"}

  test "stream_fetch!/2", %{bypass: bypass, url: url, auth_token: token} do
    Bypass.expect(bypass, "GET", "/", fn conn ->
      conn =
        conn
        |> Plug.Conn.put_resp_content_type("text/event-stream")
        |> Plug.Conn.send_chunked(200)

      # send chunk data
      Plug.Conn.chunk(conn, "#{Jason.encode!(@json1)}\n#{Jason.encode!(@json2)}\n")
      Plug.Conn.chunk(conn, "#{Jason.encode!(@json3)}\n")
      conn
    end)

    assert url
           |> Query.stream_fetch!(token)
           |> Enum.map(&Jason.decode!/1) == [@json1, @json2, @json3]
  end

  test "stream_fetch!/2 with jsonl across chunks", %{bypass: bypass, url: url, auth_token: token} do
    Bypass.expect(bypass, "GET", "/", fn conn ->
      conn =
        conn
        |> Plug.Conn.put_resp_content_type("text/event-stream")
        |> Plug.Conn.send_chunked(200)

      # send chunk data
      {json2a, json2b} = @json2 |> Jason.encode!() |> String.split_at(13)
      Plug.Conn.chunk(conn, "#{Jason.encode!(@json1)}\n#{json2a}")
      Plug.Conn.chunk(conn, "#{json2b}\n#{Jason.encode!(@json3)}\n")
      conn
    end)

    assert url
           |> Query.stream_fetch!(token)
           |> Enum.map(&Jason.decode!/1) == [@json1, @json2, @json3]
  end

  test "stream_fetch!/2 with non-200 response codes", %{
    bypass: bypass,
    url: url,
    auth_token: token
  } do
    Bypass.expect(bypass, "GET", "/", fn conn ->
      conn =
        conn
        |> Plug.Conn.put_resp_content_type("text/event-stream")
        |> Plug.Conn.send_chunked(500)

      # send chunk data
      Plug.Conn.chunk(conn, "#{Jason.encode!(@json1)}\n")
      conn
    end)

    assert_raise(RuntimeError, fn ->
      url |> Query.stream_fetch!(token) |> Enum.to_list()
    end)
  end
end
