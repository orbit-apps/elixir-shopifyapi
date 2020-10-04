defmodule Test.ShopifyAPI.RouterTest do
  use ExUnit.Case
  use Plug.Test

  alias ShopifyAPI.{App, Shop}
  alias ShopifyAPI.{AppServer, AuthTokenServer, ConnHelpers, ShopServer}
  alias ShopifyAPI.{JSONSerializer, Router}

  alias Plug.{Conn, Parsers}

  @moduletag :capture_log

  def parse(conn, opts \\ []) do
    opts = Keyword.put_new(opts, :parsers, [Plug.Parsers.URLENCODED, Plug.Parsers.MULTIPART])
    Parsers.call(conn, Parsers.init(opts))
  end

  @code "testing"
  @app_name "test"
  @nonce "testing"
  @redirect_uri "example.com"
  @shop_domain "shop.myshopify.com"
  @timestamp "1234"
  @client_secret "5fd0b04756f115ecb0820cabc1779a2286e32b66501936c9d7103907bcba9ef1"

  setup_all do
    AppServer.set(@app_name, %App{
      auth_redirect_uri: @redirect_uri,
      client_secret: @client_secret,
      name: @app_name,
      nonce: @nonce,
      scope: "nothing"
    })

    ShopServer.set(%Shop{domain: @shop_domain})

    Application.put_env(:shopify_api, ShopifyAPI.Authorizer,
      uri: "https://example.com/app",
      post_install: {PostAuthModule, :post_install},
      run_app: {PostAuthModule, :run_app}
    )

    :ok
  end

  describe "/start/:app" do
    test "with a valid app it redirects" do
      conn =
        :get
        |> conn("/start/#{@app_name}?#{add_hmac_to_params()}")
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
        |> conn("/start/not-an-app?#{add_hmac_to_params(%{app_name: "not-an-app"})}")
        |> parse()
        |> Router.call(%{})

      assert conn.status == 404
    end
  end

  describe "/install/:app" do
    @code "testing"
    @token %{access_token: "test-token"}

    setup _contxt do
      bypass = Bypass.open(port: Application.get_env(:shopify_api, :bypass_port))
      auth_server = "#{Application.get_env(:shopify_api, :bypass_host)}:#{bypass.port}"
      ShopServer.set(%Shop{domain: @shop_domain})

      {:ok, %{bypass: bypass, shop_domain: @shop_domain, auth_server: auth_server}}
    end

    test "fails with invalid hmac", %{bypass: _bypass, shop_domain: shop_domain} do
      conn =
        :get
        |> conn(
          "/install/#{@app_name}?#{
            add_hmac_to_params(%{shop_domain: shop_domain, hmac: "invalid"})
          }"
        )
        |> parse()
        |> Router.call(%{})

      assert conn.status == 404
    end

    test "fetches the token", %{bypass: bypass, shop_domain: shop_domain} do
      Bypass.expect(bypass, fn conn ->
        {:ok, body} = JSONSerializer.encode(@token)
        Conn.resp(conn, 200, body)
      end)

      conn =
        :get
        |> conn(
          "/install/#{@app_name}?" <>
            add_hmac_to_params(%{shop_domain: shop_domain})
        )
        |> parse()
        |> Router.call(%{})

      assert conn.status == 200
      {:ok, %{token: auth_token}} = AuthTokenServer.get(shop_domain, @app_name)
      assert auth_token == @token.access_token
    end

    test "fails without a valid nonce", %{bypass: _bypass, shop_domain: shop_domain} do
      conn =
        :get
        |> conn(
          "/install/#{@app_name}?" <>
            add_hmac_to_params(%{shop_domain: shop_domain, nonce: "invalid"})
        )
        |> parse()
        |> Router.call(%{})

      assert conn.status == 404
    end

    test "fails without a valid app", %{bypass: _bypass, shop_domain: shop_domain} do
      conn =
        :get
        |> conn(
          "/install/invalid-app?" <>
            add_hmac_to_params(%{shop_domain: shop_domain})
        )
        |> parse()
        |> Router.call(%{})

      assert conn.status == 404
    end

    test "fails without a valid shop", %{bypass: _bypass} do
      conn =
        :get
        |> conn(
          "/install/#{@app_name}?" <>
            add_hmac_to_params(%{shop_domain: "invalid-shop"})
        )
        |> parse()
        |> Router.call(%{})

      assert conn.status == 404
    end
  end

  describe "/run/:app" do
    @code "testing"

    setup _contxt do
      bypass = Bypass.open(port: Application.get_env(:shopify_api, :bypass_port))
      auth_server = "#{Application.get_env(:shopify_api, :bypass_host)}:#{bypass.port}"
      ShopServer.set(%Shop{domain: @shop_domain})

      {:ok, %{bypass: bypass, shop_domain: @shop_domain, auth_server: auth_server}}
    end

    test "fails with invalid hmac", %{bypass: _bypass, shop_domain: shop_domain} do
      conn =
        :get
        |> conn(
          "/run/#{@app_name}?#{add_hmac_to_params(%{shop_domain: shop_domain, hmac: "invalid"})}"
        )
        |> parse()
        |> Router.call(%{})

      assert conn.status == 404
    end

    test "fails without a valid nonce", %{bypass: _bypass, shop_domain: shop_domain} do
      conn =
        :get
        |> conn(
          "/run/#{@app_name}?" <>
            add_hmac_to_params(%{shop_domain: shop_domain, nonce: "invalid"})
        )
        |> parse()
        |> Router.call(%{})

      assert conn.status == 404
    end

    test "fails without a valid app", %{bypass: _bypass, shop_domain: shop_domain} do
      conn =
        :get
        |> conn(
          "/run/invalid-app?" <>
            add_hmac_to_params(%{shop_domain: shop_domain})
        )
        |> parse()
        |> Router.call(%{})

      assert conn.status == 404
    end

    test "fails without a valid shop", %{bypass: _bypass} do
      conn =
        :get
        |> conn(
          "/run/#{@app_name}?" <>
            add_hmac_to_params(%{shop_domain: "invalid-shop"})
        )
        |> parse()
        |> Router.call(%{})

      assert conn.status == 404
    end
  end

  def add_hmac_to_params(params \\ %{}) do
    t = params[:timestamp] || @timestamp
    a = params[:app_name] || @app_name
    d = params[:shop_domain] || @shop_domain
    n = params[:nonce] || @nonce
    c = params[:code] || @code
    s = params[:secret] || @client_secret

    h =
      params[:hmac] ||
        ConnHelpers.build_hmac_from_params(
          %{
            "timestamp" => t,
            "app" => a,
            "shop" => d,
            "state" => n,
            "code" => c
          },
          s
        )

    "timestamp=#{t}&app=#{a}&shop=#{d}&state=#{n}&code=#{c}&hmac=#{h}"
  end
end

defmodule PostAuthModule do
  def run_app(conn) do
    conn
    |> Plug.Conn.resp(200, "Authenticated.")
    |> Plug.Conn.halt()
  end

  def post_install(conn) do
    conn
    |> Plug.Conn.resp(200, "Authenticated.")
    |> Plug.Conn.halt()
  end
end
