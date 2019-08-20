defmodule ShopifyAPI.GraphQL.ResponseTest do
  use ExUnit.Case

  alias ShopifyAPI.GraphQL.Response

  @httpoison_response {:ok,
                       %HTTPoison.Response{
                         body:
                           "{\"data\":{\"metafield1\":{\"deletedId\":\"gid://shopify/Metafield/5256098316335\",\"userErrors\":[]}},\"extensions\":{\"cost\":{\"actualQueryCost\":10,\"fields\":[{\"definedCost\":10,\"path\":[\"metafield1\"],\"requestedChildrenCost\":0,\"requestedTotalCost\":10}],\"requestedQueryCost\":10,\"throttleStatus\":{\"currentlyAvailable\":990,\"maximumAvailable\":1.0e3,\"restoreRate\":50.0}}}}",
                         headers: [
                           {"cache-control", "max-age=0, private, must-revalidate"},
                           {"content-length", "352"},
                           {"date", "Tue, 20 Aug 2019 20:27:42 GMT"},
                           {"server", "Cowboy"}
                         ],
                         request: %HTTPoison.Request{
                           body:
                             "mutation {\n    metafield1: metafieldDelete (input: {id: \"gid://shopify/Metafield/123456789\"}){\n    deletedId\n    userErrors {\n      field\n      message\n      }\n    }\n  }",
                           headers: [
                             {"Content-Type", "application/graphql"},
                             {"X-Shopify-Access-Token", "1234"}
                           ],
                           method: :post,
                           options: [
                             token: %ShopifyAPI.AuthToken{
                               app_name: "",
                               code: "",
                               plus: false,
                               shop_name: "localhost:60370",
                               timestamp: 0,
                               token: "1234"
                             }
                           ],
                           params: %{},
                           url: "http://localhost:60370/admin/api/2019-07/graphql.json"
                         },
                         request_url: "http://localhost:60370/admin/api/2019-07/graphql.json",
                         status_code: 200
                       }}

  @httpoison_error_response {:ok,
                             %HTTPoison.Response{
                               body:
                                 "[{\"message\":\"Query has a cost of 1100, which exceeds the max cost of 1000\"}]",
                               headers: [
                                 {"cache-control", "max-age=0, private, must-revalidate"},
                                 {"content-length", "76"},
                                 {"date", "Tue, 20 Aug 2019 20:30:20 GMT"},
                                 {"server", "Cowboy"}
                               ],
                               request: %HTTPoison.Request{
                                 body:
                                   "mutation {\n    metafield1: metafieldDelete (input: {id: \"gid://shopify/Metafield/123456789\"}){\n    deletedId\n    userErrors {\n      field\n      message\n      }\n    }\n  }",
                                 headers: [
                                   {"Content-Type", "application/graphql"},
                                   {"X-Shopify-Access-Token", "1234"}
                                 ],
                                 method: :post,
                                 options: [
                                   token: %ShopifyAPI.AuthToken{
                                     app_name: "",
                                     code: "",
                                     plus: false,
                                     shop_name: "localhost:60536",
                                     timestamp: 0,
                                     token: "1234"
                                   }
                                 ],
                                 params: %{},
                                 url: "http://localhost:60536/admin/api/2019-07/graphql.json"
                               },
                               request_url:
                                 "http://localhost:60536/admin/api/2019-07/graphql.json",
                               status_code: 200
                             }}

  describe "Response handle/1" do
    test "when response is succesful" do
      success =
        {:ok,
         %ShopifyAPI.GraphQL.Response{
           metadata: %{
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
           },
           response: %{
             "metafield1" => %{
               "deletedId" => "gid://shopify/Metafield/5256098316335",
               "userErrors" => []
             }
           },
           status_code: 200,
           headers: [
             {"cache-control", "max-age=0, private, must-revalidate"},
             {"content-length", "352"},
             {"date", "Tue, 20 Aug 2019 20:27:42 GMT"},
             {"server", "Cowboy"}
           ]
         }}

      assert success == Response.handle(@httpoison_response)
    end

    test "when request fails" do
      error =
        {:error,
         %HTTPoison.Response{
           body: [%{"message" => "Query has a cost of 1100, which exceeds the max cost of 1000"}],
           headers: [
             {"cache-control", "max-age=0, private, must-revalidate"},
             {"content-length", "76"},
             {"date", "Tue, 20 Aug 2019 20:30:20 GMT"},
             {"server", "Cowboy"}
           ],
           request: %HTTPoison.Request{
             body:
               "mutation {\n    metafield1: metafieldDelete (input: {id: \"gid://shopify/Metafield/123456789\"}){\n    deletedId\n    userErrors {\n      field\n      message\n      }\n    }\n  }",
             headers: [
               {"Content-Type", "application/graphql"},
               {"X-Shopify-Access-Token", "1234"}
             ],
             method: :post,
             options: [
               token: %ShopifyAPI.AuthToken{
                 app_name: "",
                 code: "",
                 plus: false,
                 shop_name: "localhost:60536",
                 timestamp: 0,
                 token: "1234"
               }
             ],
             params: %{},
             url: "http://localhost:60536/admin/api/2019-07/graphql.json"
           },
           request_url: "http://localhost:60536/admin/api/2019-07/graphql.json",
           status_code: 200
         }}

      assert error == Response.handle(@httpoison_error_response)
    end

    test "when json decode fails" do
      error =
        {:error,
         %ShopifyAPI.GraphQL.JSONParseError{
           error: %Jason.DecodeError{
             data: "{\"data\": null, \"errors\": }",
             position: 25,
             token: nil
           },
           response: %HTTPoison.Response{
             body: "{\"data\": null, \"errors\": }",
             headers: [],
             request: nil,
             request_url: nil,
             status_code: nil
           }
         }}

      payload = {:ok, %HTTPoison.Response{body: ~s/{"data": null, "errors": }/}}

      assert error == Response.handle(payload)
    end
  end
end
