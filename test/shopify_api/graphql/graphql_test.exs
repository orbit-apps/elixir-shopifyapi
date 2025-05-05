defmodule ShopifyAPI.GraphQL.GraphQLTest do
  use ExUnit.Case

  import ShopifyAPI.Factory
  import ShopifyAPI.SessionTokenSetup

  alias Plug.Conn

  alias ShopifyAPI.GraphQL
  alias ShopifyAPI.GraphQL.Response
  alias ShopifyAPI.JSONSerializer

  @data %{
    "metafield1" => %{
      "deletedId" => "gid://shopify/Metafield/5256098316335",
      "userErrors" => []
    }
  }

  @data_does_not_exist %{
    "metafield1" => %{
      "deletedId" => nil,
      "userErrors" => [
        %{"field" => ["id"], "message" => "Metafield does not exist"}
      ]
    }
  }

  @cost_exceeded [%{"message" => "Query has a cost of 1100, which exceeds the max cost of 1000"}]

  @metadata %{
    "cost" => %{
      "actualQueryCost" => 10,
      "fields" => [
        %{
          "definedCost" => 10,
          "path" => ["metafield1"],
          "requestedChildrenCost" => 0,
          "requestedTotalCost" => 10
        }
      ],
      "requestedQueryCost" => 10,
      "throttleStatus" => %{
        "currentlyAvailable" => 990,
        "maximumAvailable" => 1.0e3,
        "restoreRate" => 50.0
      }
    }
  }

  @row_query_string "mutation {metafield0: metafieldDelete (input: {id: \"gid://shopify/Metafield/9208558682200\"}){deletedId userErrors {field message }}}"

  @query_string "mutation metafieldDelete($input: MetafieldDeleteInput!){metafieldDelete(input: $input) {deletedId userErrors {field message }}}"

  @variables %{input: %{id: "gid://shopify/Metafield/9208558682200"}}

  setup _context do
    bypass = Bypass.open()
    {:ok, [bypass: bypass, shop: build(:shop, domain: "localhost:#{bypass.port}")]}
  end

  setup [:offline_token]

  describe "GraphQL query/2" do
    test "when mutation has parametized variables", %{
      bypass: bypass,
      shop: _shop,
      offline_token: token
    } do
      response = Map.merge(%{"data" => @data}, %{"extensions" => @metadata})

      Bypass.expect_once(
        bypass,
        "POST",
        "/admin/api/#{GraphQL.configured_version()}/graphql.json",
        fn conn ->
          {:ok, body} = JSONSerializer.encode(response)
          Conn.resp(conn, 200, body)
        end
      )

      assert {:ok, %Response{response: @data, metadata: @metadata, status_code: 200}} =
               GraphQL.query(token, @query_string, @variables)
    end

    test "when mutation is a query string", %{
      bypass: bypass,
      shop: _shop,
      offline_token: token
    } do
      response = Map.merge(%{"data" => @data}, %{"extensions" => @metadata})

      Bypass.expect_once(
        bypass,
        "POST",
        "/admin/api/#{GraphQL.configured_version()}/graphql.json",
        fn conn ->
          {:ok, body} = JSONSerializer.encode(response)
          Conn.resp(conn, 200, body)
        end
      )

      assert {:ok, %Response{response: @data, metadata: @metadata, status_code: 200}} =
               GraphQL.query(token, @row_query_string)
    end

    test "when deleting a metafield that does not exist", %{
      bypass: bypass,
      shop: _shop,
      offline_token: token
    } do
      response = Map.merge(%{"data" => @data_does_not_exist}, %{"extensions" => @metadata})

      Bypass.expect_once(
        bypass,
        "POST",
        "/admin/api/#{GraphQL.configured_version()}/graphql.json",
        fn conn ->
          {:ok, body} = JSONSerializer.encode(response)
          Conn.resp(conn, 200, body)
        end
      )

      assert {:ok,
              %Response{response: @data_does_not_exist, metadata: @metadata, status_code: 200}} =
               GraphQL.query(token, @query_string, @variables)
    end

    test "when query exceeds max cost for 1000", %{
      bypass: bypass,
      shop: _shop,
      offline_token: token
    } do
      Bypass.expect_once(
        bypass,
        "POST",
        "/admin/api/#{GraphQL.configured_version()}/graphql.json",
        fn conn ->
          {:ok, body} = JSONSerializer.encode(@cost_exceeded)
          Conn.resp(conn, 200, body)
        end
      )

      assert {:error, %HTTPoison.Response{}} = GraphQL.query(token, @query_string, @variables)
    end
  end

  describe "Response remaining_points/1" do
    test "when response contains metadata", %{
      bypass: bypass,
      shop: _shop,
      offline_token: token
    } do
      response = Map.merge(%{"data" => @data}, %{"extensions" => @metadata})

      Bypass.expect_once(
        bypass,
        "POST",
        "/admin/api/#{GraphQL.configured_version()}/graphql.json",
        fn conn ->
          {:ok, body} = JSONSerializer.encode(response)
          Conn.resp(conn, 200, body)
        end
      )

      rate_limit_details =
        token
        |> GraphQL.query(@query_string, @variables)
        |> GraphQL.rate_limit_details()

      assert %{
               actual_cost: 10,
               currently_available: 990,
               maximum_available: 1000
             } == rate_limit_details
    end

    test "when response does not contain metadata", %{
      bypass: bypass,
      shop: _shop,
      offline_token: token
    } do
      Bypass.expect_once(
        bypass,
        "POST",
        "/admin/api/#{GraphQL.configured_version()}/graphql.json",
        fn conn ->
          {:ok, body} = JSONSerializer.encode(@cost_exceeded)
          Conn.resp(conn, 200, body)
        end
      )

      rate_limit_details =
        token
        |> GraphQL.query(@query_string, @variables)
        |> GraphQL.rate_limit_details()

      assert %{
               actual_cost: nil,
               currently_available: nil,
               maximum_available: nil
             } == rate_limit_details
    end
  end
end
