defmodule ShopifyAPI.GraphQL.BulkFetchTest do
  use ExUnit.Case

  alias ShopifyAPI.GraphQL.BulkFetch

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

    {:ok, %{shop: shop, auth_token: token, bypass: bypass}}
  end

  test "happy path", %{bypass: bypass, shop: _shop, auth_token: token} do
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

    assert {:ok, _} = BulkFetch.fetch_jsonl(token, "fake_query", 100, 2)
  end

  test "polling timeout", %{bypass: bypass, shop: _shop, auth_token: token} do
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

    resp = BulkFetch.fetch_jsonl(token, "fake_query", 1, 100)
    assert resp == {:error, "BulkFetch timed out before completion"}
  end

  test "invalid graphql", %{bypass: bypass, shop: _shop, auth_token: token} do
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

    resp = BulkFetch.fetch_jsonl(token, "fake_query", 100, 2)
    assert resp == {:error, "Bulk query is not valid GraphQL"}
  end
end
