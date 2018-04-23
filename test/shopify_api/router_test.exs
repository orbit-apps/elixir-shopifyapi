defmodule ShopifyApi.RouterTest do
  use ExUnit.Case
  use Plug.Test

  def parse(conn, opts \\ []) do
    opts = Keyword.put_new(opts, :parsers, [Plug.Parsers.URLENCODED, Plug.Parsers.MULTIPART])
    Plug.Parsers.call(conn, Plug.Parsers.init(opts))
  end

  @app_name "test"
  @redirect_uri "example.com"
  @shop_domain "shop.example.com"

  setup do
    ShopifyApi.AppServer.set(@app_name, %{name: @app_name, auth_redirect_uri: @redirect_uri})
    ShopifyApi.ShopServer.set(%{domain: @shop_domain})
  end

  describe "/install" do
    test "with a valid app it redirects" do
      conn =
        conn(:get, "/install?app=#{@app_name}&shop=#{@shop_domain}")
        |> parse
        |> ShopifyApi.Router.call(%{})

      assert conn.status == 302

      {"location", redirect_uri} =
        Enum.find(conn.resp_headers, fn h -> elem(h, 0) == "location" end)

      parsed = URI.parse(redirect_uri)
      assert parsed.host == @shop_domain
    end

    test "without a valid app it errors" do
      conn =
        conn(:get, "/install?app=not-an-app")
        |> parse
        |> ShopifyApi.Router.call(%{})

      assert conn.status == 404
    end
  end

  describe "/authoized" do
    @code "testing"

    test "fetches the token" do
      conn =
        conn(:get, "/authorized/#{@app_name}?shop=#{shop_domain}&code=#{@code}&timestamp=1234")
        |> parse
        |> ShopifyApi.Router.call(%{})
    end
  end
end
