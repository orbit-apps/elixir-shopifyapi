defmodule ShopifyAPI.BypassSetup do
  import ShopifyAPI.Factory

  alias ShopifyAPI.GraphQL
  alias ShopifyAPI.JSONSerializer

  alias Plug.Conn

  def bypass(_context) do
    bypass = Bypass.open()
    myshopify_domain = "localhost:#{bypass.port}"
    shop = build(:shop, domain: myshopify_domain)
    {:ok, [bypass: bypass, shop: shop, myshopify_domain: myshopify_domain]}
  end

  def expect_once(bypass, responose) do
    response_string = JSONSerializer.encode!(responose)

    Bypass.expect_once(
      bypass,
      "POST",
      "/admin/api/#{GraphQL.configured_version()}/graphql.json",
      fn conn -> Conn.resp(conn, 200, response_string) end
    )
  end
end
