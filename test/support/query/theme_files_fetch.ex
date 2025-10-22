defmodule ShopifyAPI.Support.Query.ThemesFilesFetch do
  use ShopifyAPI.GraphQL.GraphQLQuery

  alias ShopifyAPI.GraphQL.GraphQLQuery

  @themes_files_fetch """
  query themeFilesFetch($files: [String!], $theme_id: ID!) {
    themeFilesFetch: theme(id: $theme_id) {
      id
      name
      role
      files(filenames: $files, first: 250) {
        nodes {
          filename
          body {
            ... on OnlineStoreThemeFileBodyText {
              content
            }
          }
        }
      }
    }
  }
  """

  def query_string, do: @themes_files_fetch
  def name, do: "themeFilesFetch"
  def path, do: ["files", "nodes", GraphQLQuery.access_map(["filename"], ["body", "content"])]

  @success_response %{
    "data" => %{
      "themeFilesFetch" => %{
        "files" => %{
          "nodes" => [
            %{
              "body" => %{
                "content" => "redacted content"
              },
              "filename" => "layout/theme.liquid"
            }
          ]
        },
        "id" => "gid://shopify/Shop/10000000000",
        "name" => "Rise",
        "role" => "UNPUBLISHED"
      }
    },
    "extensions" => %{
      "cost" => %{
        "actualQueryCost" => 5,
        "requestedQueryCost" => 24,
        "throttleStatus" => %{
          "currentlyAvailable" => 1983,
          "maximumAvailable" => 2000.0,
          "restoreRate" => 100.0
        }
      }
    }
  }

  def success_response, do: @success_response
end
