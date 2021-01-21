defmodule ShopifyAPI.Bulk.QueryTest do
  use ExUnit.Case

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

  setup _context do
    bypass = Bypass.open()

    Application.put_env(:shopify_api, ShopifyAPI.GraphQL, graphql_version: @graphql_ver)

    token = %ShopifyAPI.AuthToken{
      token: "token",
      shop_name: "localhost:#{bypass.port}"
    }

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
                "A bulk operation for this app and shop is already in progress: gid://fake-bulk-op-id"
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
