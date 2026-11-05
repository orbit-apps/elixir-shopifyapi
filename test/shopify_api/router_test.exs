defmodule Test.ShopifyAPI.RouterTest do
  use ExUnit.Case

  import Plug.Test

  alias ShopifyAPI.{App, Shop}
  alias ShopifyAPI.{AppServer, AuthTokenServer, ShopServer}
  alias ShopifyAPI.{JSONSerializer, Router, Security}

  alias Plug.{Conn, Parsers}

  @moduletag :capture_log

  def parse(conn, opts \\ []) do
    opts = Keyword.put_new(opts, :parsers, [Plug.Parsers.URLENCODED, Plug.Parsers.MULTIPART])
    Parsers.call(conn, Parsers.init(opts))
  end

  @app_name "test"
  @client_secret "test"
  @nonce "testing"
  @redirect_uri "example.com"
  @shop_domain "shop.myshopify.com"

  setup_all do
    AppServer.set(@app_name, %App{
      auth_redirect_uri: @redirect_uri,
      client_secret: @client_secret,
      name: @app_name,
      nonce: @nonce,
      scope: "nothing"
    })

    ShopServer.set(%Shop{domain: @shop_domain})
    :ok
  end

  describe "/install" do
    test "with a valid app it redirects" do
      conn =
        :get
        |> conn("/install?app=#{@app_name}&shop=#{@shop_domain}")
        |> parse()
        |> Router.call(%{})

      assert conn.status == 302

      {"location", redirect_uri} =
        Enum.find(conn.resp_headers, fn h -> elem(h, 0) == "location" end)

      assert URI.parse(redirect_uri).host == @shop_domain
    end

    test "without a valid app it errors" do
      conn =
        :get
        |> conn("/install?app=not-an-app&shop=#{@shop_domain}")
        |> parse()
        |> Router.call(%{})

      assert conn.status == 404
    end

    test "without a shop it errors" do
      conn =
        :get
        |> conn("/install?app=#{@app_name}")
        |> parse()
        |> Router.call(%{})

      assert conn.status == 404
    end

    test "with a shop outside myshopify.com it errors" do
      conn =
        :get
        |> conn("/install?app=#{@app_name}&shop=evil.example.com")
        |> parse()
        |> Router.call(%{})

      assert conn.status == 404
    end

    test "with a shop header outside myshopify.com it errors" do
      conn =
        :get
        |> conn("/install?app=#{@app_name}&shop=#{@shop_domain}")
        |> Conn.put_req_header("x-shopify-shop-domain", "evil.example.com")
        |> parse()
        |> Router.call(%{})

      assert conn.status == 404
    end
  end

  describe "/authorized" do
    @code "testing"
    @token %{access_token: "test-token"}

    setup _contxt do
      bypass = Bypass.open()
      shop_domain = "localhost:#{bypass.port}"
      ShopServer.set(%Shop{domain: shop_domain})

      {:ok, %{bypass: bypass, shop_domain: shop_domain}}
    end

    test "fails with invalid hmac", %{bypass: _bypass, shop_domain: shop_domain} do
      conn =
        :get
        |> conn(
          "/authorized/#{@app_name}?shop=#{shop_domain}&code=#{@code}&timestamp=1234&hmac=invalid"
        )
        |> parse()
        |> Router.call(%{})

      assert conn.status == 404
    end

    test "fetches the token", %{bypass: bypass, shop_domain: shop_domain} do
      Bypass.expect_once(bypass, "POST", "/admin/oauth/access_token", fn conn ->
        {:ok, body} = JSONSerializer.encode(@token)
        Conn.resp(conn, 200, body)
      end)

      conn =
        :get
        |> conn(
          "/authorized/#{@app_name}?" <>
            add_hmac_to_params("code=#{@code}&shop=#{shop_domain}&state=#{@nonce}&timestamp=1234")
        )
        |> parse()
        |> Router.call(%{})

      assert conn.status == 302
      {:ok, %{token: auth_token}} = AuthTokenServer.get(shop_domain, @app_name)
      assert auth_token == @token.access_token
    end

    test "fails without a valid nonce", %{bypass: _bypass, shop_domain: shop_domain} do
      conn =
        :get
        |> conn(
          "/authorized/invalid-app?" <>
            add_hmac_to_params("code=#{@code}&shop=#{shop_domain}&state=invalid&timestamp=1234")
        )
        |> parse()
        |> Router.call(%{})

      assert conn.status == 404
    end

    test "fails without a valid app", %{bypass: _bypass, shop_domain: shop_domain} do
      conn =
        :get
        |> conn(
          "/authorized/invalid-app?" <>
            add_hmac_to_params("code=#{@code}&shop=#{shop_domain}&state=#{@nonce}&timestamp=1234")
        )
        |> parse()
        |> Router.call(%{})

      assert conn.status == 404
    end

    test "fails without a valid shop", %{bypass: _bypass} do
      conn =
        :get
        |> conn(
          "/authorized/#{@app_name}?" <>
            add_hmac_to_params("code=#{@code}&shop=invalid-shop&state=#{@nonce}&timestamp=1234")
        )
        |> parse()
        |> Router.call(%{})

      assert conn.status == 404
    end

    test "sends the client secret to the signed shop, not the shop header", %{
      bypass: bypass,
      shop_domain: shop_domain
    } do
      # Bypass fails the test if this server receives any request.
      spoofed = Bypass.open()
      spoofed_domain = "localhost:#{spoofed.port}"

      Bypass.expect_once(bypass, "POST", "/admin/oauth/access_token", fn conn ->
        {:ok, body} = JSONSerializer.encode(@token)
        Conn.resp(conn, 200, body)
      end)

      conn =
        :get
        |> conn(
          "/authorized/#{@app_name}?" <>
            add_hmac_to_params("code=#{@code}&shop=#{shop_domain}&state=#{@nonce}&timestamp=1234")
        )
        |> Conn.put_req_header("x-shopify-shop-domain", spoofed_domain)
        |> parse()
        |> Router.call(%{})

      assert conn.status == 302
      assert {:ok, _token} = AuthTokenServer.get(shop_domain, @app_name)
      assert {:error, _reason} = AuthTokenServer.get(spoofed_domain, @app_name)
    end

    test "fails with a signed shop outside myshopify.com" do
      conn =
        :get
        |> conn(
          "/authorized/#{@app_name}?" <>
            add_hmac_to_params(
              "code=#{@code}&shop=evil.example.com&state=#{@nonce}&timestamp=1234"
            )
        )
        |> parse()
        |> Router.call(%{})

      assert conn.status == 404
    end

    test "fails with a signed query that has no shop" do
      conn =
        :get
        |> conn(
          "/authorized/#{@app_name}?" <>
            add_hmac_to_params("code=#{@code}&state=#{@nonce}&timestamp=1234")
        )
        |> Conn.put_req_header("x-shopify-shop-domain", @shop_domain)
        |> parse()
        |> Router.call(%{})

      assert conn.status == 404
    end

    test "with no code and a shop outside myshopify.com it does not start an install" do
      conn =
        :get
        |> conn("/authorized/#{@app_name}?shop=evil.example.com")
        |> parse()
        |> Router.call(%{})

      assert conn.status == 404
    end

    def add_hmac_to_params(params) do
      params <> "&hmac=" <> Security.base16_sha256_hmac(params, @client_secret)
    end
  end
end
