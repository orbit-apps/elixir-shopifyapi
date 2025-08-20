defmodule ShopifyAPI.GraphQL.GraphQLQueryTest do
  use ExUnit.Case, async: true

  import ShopifyAPI.Factory
  import ShopifyAPI.SessionTokenSetup
  import ShopifyAPI.BypassSetup

  alias ShopifyAPI.GraphQL.GraphQLQuery
  alias ShopifyAPI.GraphQL.GraphQLResponse

  alias ShopifyAPI.Support.Query.FetchShop
  alias ShopifyAPI.Support.Query.ThemeFileCopy
  alias ShopifyAPI.Support.Query.ThemesFilesFetch

  doctest ShopifyAPI.GraphQL.GraphQLQuery

  setup [:bypass, :offline_token]

  describe "modules using GraphQLQuery" do
    test "make a successful graphql request", %{
      bypass: bypass,
      offline_token: scope
    } do
      expect_once(bypass, FetchShop.success_response())

      assert {:ok, shop} =
               FetchShop.query() |> FetchShop.execute(scope) |> GraphQLResponse.resolve()

      assert shop["id"] == "gid://shopify/Shop/10000000000"
    end

    test "handles userErrors responses ", %{
      bypass: bypass,
      shop: _shop,
      offline_token: scope
    } do
      expect_once(bypass, ThemeFileCopy.user_errors_response())

      variables = %{
        theme_id: "gid://shopify/Shop/10000000000",
        files: [
          %{"srcFilename" => "templates/index.json", "dstFilename" => "layout/deleteme.json"}
        ]
      }

      assert {:error, %GraphQLResponse{} = response} =
               ThemeFileCopy.query()
               |> ThemeFileCopy.assigns(variables)
               |> ThemeFileCopy.execute(scope)
               |> GraphQLResponse.resolve()

      assert [%{"field" => ["files"], "message" => _} | _] = response.user_errors
    end

    test "handles error responses", %{
      bypass: bypass,
      shop: _shop,
      offline_token: scope
    } do
      expect_once(bypass, ThemeFileCopy.error_response())

      variables = %{
        theme_id: "gid://shopify/Shop/invalid",
        files: [
          %{"srcFilename" => "templates/index.json", "dstFilename" => "layout/deleteme.json"}
        ]
      }

      assert {:error, %GraphQLResponse{} = response} =
               ThemeFileCopy.query()
               |> ThemeFileCopy.assigns(variables)
               |> ThemeFileCopy.execute(scope)
               |> GraphQLResponse.resolve()

      assert [%{"path" => ["themeFilesCopy"], "message" => "invalid id"} | _] = response.errors
    end

    test "decomposes complex responses", %{
      bypass: bypass,
      shop: _shop,
      offline_token: scope
    } do
      expect_once(bypass, ThemesFilesFetch.success_response())

      variables = %{
        theme_id: "gid://shopify/Shop/10000000000",
        files: ["layout/theme.liquid"]
      }

      assert {:ok, results} =
               ThemesFilesFetch.query()
               |> ThemesFilesFetch.assigns(variables)
               |> ThemesFilesFetch.execute(scope)
               |> GraphQLResponse.resolve()

      assert results == %{"layout/theme.liquid" => "redacted content"}
    end
  end
end
