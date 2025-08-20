defmodule ShopifyAPI.Support.Query.FetchShop do
  use ShopifyAPI.GraphQL.GraphQLQuery

  @theme_list """
  query {
    shop {
      id
      createdAt
      email
      contactEmail
      shopOwnerName
      name
      plan {
        shopifyPlus
      }
      url
      ianaTimezone
    }
  }
  """

  def query_string, do: @theme_list
  def name, do: "shop"
  def path, do: []

  @success_response %{
    "data" => %{
      "shop" => %{
        "contactEmail" => "email@example.com",
        "createdAt" => "2024-07-31T00:55:30Z",
        "email" => "email@example.com",
        "ianaTimezone" => "America/New_York",
        "id" => "gid://shopify/Shop/10000000000",
        "name" => "example_shop",
        "plan" => %{"shopifyPlus" => false},
        "shopOwnerName" => "Example Owner",
        "url" => "https://example_shop.myshopify.com"
      }
    },
    "extensions" => %{
      "cost" => %{
        "actualQueryCost" => 2,
        "requestedQueryCost" => 2,
        "throttleStatus" => %{
          "currentlyAvailable" => 1998,
          "maximumAvailable" => 2000.0,
          "restoreRate" => 100.0
        }
      }
    }
  }
  def success_response, do: @success_response
end
