defmodule ShopifyAPI.Support.Query.ThemeFileCopy do
  use ShopifyAPI.GraphQL.GraphQLQuery

  @theme_files_copy """
  mutation themeFilesCopy($files: [ThemeFilesCopyFileInput!]!, $theme_id: ID!) {
    themeFilesCopy(files: $files, themeId: $theme_id) {
      copiedThemeFiles {
        filename
      }
      userErrors {
        field
        message
      }
    }
  }
  """

  def query_string, do: @theme_files_copy
  def name, do: "themeFilesCopy"
  def path, do: ["copiedThemeFiles"]

  @error_response %{
    "data" => %{"themeFilesCopy" => nil},
    "errors" => [
      %{
        "extensions" => %{"code" => "RESOURCE_NOT_FOUND"},
        "locations" => [%{"column" => 3, "line" => 2}],
        "message" => "invalid id",
        "path" => ["themeFilesCopy"]
      }
    ],
    "extensions" => %{
      "cost" => %{
        "actualQueryCost" => 1,
        "requestedQueryCost" => 10,
        "throttleStatus" => %{
          "currentlyAvailable" => 1999,
          "maximumAvailable" => 2000.0,
          "restoreRate" => 100.0
        }
      }
    }
  }

  @user_errors_response %{
    "data" => %{
      "themeFilesCopy" => %{
        "copiedThemeFiles" => [],
        "userErrors" => [
          %{
            "field" => ["files"],
            "message" => "Missing {{content_for_header}} in the head section of the template"
          },
          %{
            "field" => ["files"],
            "message" => "Missing {{content_for_layout}} in the body section of the template"
          },
          %{
            "field" => ["files"],
            "message" => "Must have a .liquid file extension"
          }
        ]
      }
    },
    "extensions" => %{
      "cost" => %{
        "actualQueryCost" => 10,
        "requestedQueryCost" => 10,
        "throttleStatus" => %{
          "currentlyAvailable" => 1990,
          "maximumAvailable" => 2000.0,
          "restoreRate" => 100.0
        }
      }
    }
  }

  def error_response, do: @error_response
  def user_errors_response, do: @user_errors_response
end
