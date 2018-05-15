defmodule Test.ShopifyApi.RouterTest do
  use ExUnit.Case
  use Plug.Test

  def parse(conn, opts \\ []) do
    opts = Keyword.put_new(opts, :parsers, [Plug.Parsers.URLENCODED, Plug.Parsers.MULTIPART])
    Plug.Parsers.call(conn, Plug.Parsers.init(opts))
  end

  @app_name "test"
  @client_secret "test"
  @nonce "testing"
  @redirect_uri "example.com"
  @shop_domain "shop.example.com"

  setup do
    ShopifyApi.AppServer.set(@app_name, %{
      auth_redirect_uri: @redirect_uri,
      client_secret: @client_secret,
      name: @app_name,
      nonce: @nonce,
      scope: "nothing"
    })

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

      assert URI.parse(redirect_uri).host == @shop_domain
    end

    test "without a valid app it errors" do
      conn =
        conn(:get, "/install?app=not-an-app&shop=#{@shop_domain}")
        |> parse
        |> ShopifyApi.Router.call(%{})

      assert conn.status == 404
    end
  end

  describe "/authorized" do
    @code "testing"
    @token %{access_token: "test-token"}

    setup _contxt do
      bypass = Bypass.open()
      shop_domain = "localhost:#{bypass.port}"
      ShopifyApi.ShopServer.set(%{domain: shop_domain})

      {:ok, %{bypass: bypass, shop_domain: shop_domain}}
    end

    test "fails with invalid hmac", %{bypass: _bypass, shop_domain: shop_domain} do
      conn =
        conn(
          :get,
          "/authorized/#{@app_name}?shop=#{shop_domain}&code=#{@code}&timestamp=1234&hmac=invalid"
        )
        |> parse
        |> ShopifyApi.Router.call(%{})

      assert conn.status == 404
    end

    test "fetches the token", %{bypass: bypass, shop_domain: shop_domain} do
      Bypass.expect_once(bypass, "POST", "/admin/oauth/access_token", fn conn ->
        {:ok, body} = Poison.encode(@token)
        Plug.Conn.resp(conn, 200, body)
      end)

      conn =
        conn(
          :get,
          "/authorized/#{@app_name}?" <>
            add_hmac_to_params("code=#{@code}&shop=#{shop_domain}&state=#{@nonce}&timestamp=1234")
        )
        |> parse
        |> ShopifyApi.Router.call(%{})

      assert conn.status == 200
      {:ok, %{token: auth_token}} = ShopifyApi.AuthTokenServer.get(shop_domain, @app_name)
      assert auth_token == @token.access_token
    end

    test "fails without a valid nonce", %{bypass: _bypass, shop_domain: shop_domain} do
      conn =
        conn(
          :get,
          "/authorized/invalid-app?" <>
            add_hmac_to_params("code=#{@code}&shop=#{shop_domain}&state=invalid&timestamp=1234")
        )
        |> parse
        |> ShopifyApi.Router.call(%{})

      assert conn.status == 404
    end

    test "fails without a valid app", %{bypass: _bypass, shop_domain: shop_domain} do
      conn =
        conn(
          :get,
          "/authorized/invalid-app?" <>
            add_hmac_to_params("code=#{@code}&shop=#{shop_domain}&state=#{@nonce}&timestamp=1234")
        )
        |> parse
        |> ShopifyApi.Router.call(%{})

      assert conn.status == 404
    end

    test "fails without a valid shop", %{bypass: _bypass} do
      conn =
        conn(
          :get,
          "/authorized/#{@app_name}?" <>
            add_hmac_to_params("code=#{@code}&shop=invalid-shop&state=#{@nonce}&timestamp=1234")
        )
        |> parse
        |> ShopifyApi.Router.call(%{})

      assert conn.status == 404
    end

    def add_hmac_to_params(params) do
      params <> "&hmac=" <> ShopifyApi.Security.sha256_hmac(params, @client_secret)
    end
  end
end
