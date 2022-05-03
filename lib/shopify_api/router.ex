defmodule ShopifyAPI.Router do
  use Plug.Router
  require Logger

  alias Plug.Conn

  plug(:match)
  plug(:dispatch)

  @shopify_shop_header "x-shopify-shop-domain"
  @auth_code_param_name "code"

  get "/install/:app" do
    install_app(conn)
  end

  get "/install" do
    install_app(conn)
  end

  # Shopify Callback on App authorization
  get "/authorized/:app" do
    Logger.info("Authorized #{shop_domain(conn)}")

    if conn.params[@auth_code_param_name] != nil do
      with {:ok, app} <- conn |> app_name() |> ShopifyAPI.AppServer.get(),
           true <- verify_nonce(app, conn.query_params),
           true <- verify_params_with_hmac(app, conn.query_params),
           {:ok, auth_token} <- request_auth_token(conn, app) do
        auth_token |> shop_from_auth_token() |> ShopifyAPI.ShopServer.set(true)
        ShopifyAPI.AuthTokenServer.set(auth_token, true)
        ShopifyAPI.Shop.post_install(auth_token)

        conn
        |> Conn.resp(200, "Authenticated.")
        |> Conn.halt()
      else
        res ->
          Logger.info("#{__MODULE__} failed authorized with: #{inspect(res)}")

          conn
          |> Conn.resp(404, "Not Found.")
          |> Conn.halt()
      end
    else
      # No auth code given, redirect to shopify's app install page
      install_app(conn)
    end
  end

  defp verify_nonce(%_{nonce: nonce}, %{"state" => state}), do: nonce == state

  # Shopify doesn't pass the nonce back if the install was initiated from the partners dashboard.
  defp verify_nonce(_, _) do
    Logger.info("No nonce passed to install most likely dev install, skipping check")
    true
  end

  defp request_auth_token(conn, app) do
    auth_code = conn.params[@auth_code_param_name]

    app
    |> ShopifyAPI.App.fetch_token(shop_domain(conn), auth_code)
    |> case do
      {:ok, token} ->
        {:ok,
         %ShopifyAPI.AuthToken{
           app_name: app_name(conn),
           shop_name: shop_domain(conn),
           code: auth_code,
           timestamp: String.to_integer(conn.query_params["timestamp"]),
           token: token
         }}

      _msg ->
        {:error, "unable to fetch token"}
    end
  end

  defp install_app(conn) do
    conn
    |> app_name()
    |> ShopifyAPI.AppServer.get()
    |> case do
      {:ok, app} ->
        install_url = ShopifyAPI.App.install_url(app, shop_domain(conn))

        conn
        |> Conn.put_resp_header("location", install_url)
        |> Conn.resp(unquote(302), "You are being redirected.")
        |> Conn.halt()

      res ->
        Logger.info("#{__MODULE__} failed install with: #{res}")

        conn
        |> Conn.resp(404, "Not Found.")
        |> Conn.halt()
    end
  end

  defp shop_domain_from_header(conn) do
    conn
    |> Conn.get_req_header(@shopify_shop_header)
    |> List.first()
  end

  def shop_domain(conn), do: shop_domain_from_header(conn) || conn.params["shop"]

  @doc false
  defp app_name(conn), do: conn.params["app"] || List.last(conn.path_info)

  @doc false
  @spec verify_params_with_hmac(ShopifyAPI.App.t(), map()) :: boolean()
  def verify_params_with_hmac(%ShopifyAPI.App{client_secret: secret}, params) do
    params["hmac"] ==
      params
      |> Enum.reject(fn {key, _} -> key == "hmac" or key == "signature" end)
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map_join("&", fn {key, value} -> key <> "=" <> value end)
      |> ShopifyAPI.Security.base16_sha256_hmac(secret)
  end

  defp shop_from_auth_token(%ShopifyAPI.AuthToken{shop_name: myshopify_domain}),
    do: %ShopifyAPI.Shop{domain: myshopify_domain}
end
