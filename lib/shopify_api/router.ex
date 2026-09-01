defmodule ShopifyAPI.Router do
  @moduledoc """
  A `Plug.Router` implementing Shopify's OAuth install flow.

  Forward a scope to it from your own router and merchants can install the app through it:

      scope "/shop" do
        forward("/", ShopifyAPI.Router)
      end

  An embedded app does not have to use this. `ShopifyAPI.JWTSessionToken.get_offline_token/2`
  obtains the same offline token by exchanging a session token, with no redirects.

  ## Routes

    - `GET /install/:app` and `GET /install` — redirect the merchant to Shopify's authorization
      screen. Name the app either in the path, `/install/my-app`, or in an `app` query
      parameter, `/install?app=my-app`.
    - `GET /authorized/:app` — the callback Shopify redirects back to. With no `code` parameter
      it starts the install instead, which is what makes an install link from the Partner
      dashboard work.

  Both the shop domain and the app name may arrive more than one way. The domain is taken from
  the `x-shopify-shop-domain` header, falling back to a `shop` parameter. The app name is taken
  from an `app` parameter, which may be the `:app` path segment or a query string value; with
  neither it falls back to the last segment of the request path, which for a bare
  `GET /install` is `"install"` and will not match an app.

  The `:app` segment is how one deployment installs more than one Shopify app — it selects
  which `ShopifyAPI.App`, and so which client id and secret, the flow runs with. Give each app
  an `auth_redirect_uri` ending in its own name (`https://example.com/shop/authorized/my-app`)
  and a single mounted router serves them all. See `ShopifyAPI.AppServer`.

  ## What the callback does

  On `GET /authorized/:app`, in order: look up the `ShopifyAPI.App`, check the `state`
  parameter against the app's nonce, verify the query string HMAC, exchange the `code` for a
  token with `ShopifyAPI.App.fetch_token/3`, then cache the shop and the token and fire the
  `ShopifyAPI.Shop` `post_login` hook. The merchant is finally redirected to the app inside
  their admin. Any failure along the way is a bare `404`.

  Whether that token is a `ShopifyAPI.AuthToken` or a `ShopifyAPI.UserToken` depends on the
  app's access mode; each is written to its own cache.

  > #### The nonce check is skipped when absent {: .warning}
  >
  > Shopify omits `state` for installs started from the Partner dashboard, so a request with no
  > `state` parameter passes the nonce check rather than failing it. The HMAC check still
  > applies to every request.

  ## Webhooks are elsewhere

  This router handles installation only — it exposes no webhook route. Incoming webhooks are
  handled by `ShopifyAPI.Plugs.Webhook`, which mounts in your endpoint at its own `:prefix`,
  and the `ShopifyAPI.Webhook` `:uri` config must match that prefix rather than the scope this
  router is forwarded from.
  """

  use Plug.Router
  require Logger

  alias Plug.Conn
  alias ShopifyAPI.App
  alias ShopifyAPI.AppServer
  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.UserToken

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
      with {:ok, app} <- conn |> app_name() |> AppServer.get(),
           true <- verify_nonce(app, conn.query_params),
           true <- verify_params_with_hmac(app, conn.query_params),
           {:ok, auth_token} <- request_auth_token(conn, app),
           shop <- shop_from_auth_token(auth_token) do
        ShopifyAPI.ShopServer.set(shop, true)

        Logger.debug("auth_token: #{inspect(auth_token)}")

        case auth_token do
          %AuthToken{} ->
            ShopifyAPI.AuthTokenServer.set(auth_token, true)
            ShopifyAPI.Shop.post_login(auth_token)
            Logger.debug("new login for #{shop.domain}, redirecting to shopify admin")

          %UserToken{associated_user_id: associated_user_id} ->
            ShopifyAPI.UserTokenServer.set(auth_token, true)

            Logger.debug(
              "new login for user #{associated_user_id} from #{shop.domain}, redirecting to shopify admin"
            )

            ShopifyAPI.Shop.post_login(auth_token)
        end

        redirect_url = app |> installed_redirect_uri(shop) |> URI.to_string()

        conn
        |> Conn.put_resp_header("location", redirect_url)
        |> Conn.resp(unquote(302), "You are being redirected.")
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
    Logger.debug("APP #{inspect(app)}")
    myshopify_domain = shop_domain(conn)
    auth_code = conn.params[@auth_code_param_name]
    timestamp = String.to_integer(conn.query_params["timestamp"])

    case App.fetch_token(app, myshopify_domain, auth_code) do
      {:ok, %UserToken{} = token} ->
        {:ok, %{token | timestamp: timestamp}}

      {:ok, %AuthToken{} = token} ->
        {:ok, %{token | timestamp: timestamp}}

      msg ->
        Logger.debug("request_auth_token error #{inspect(msg)}}")
        {:error, "unable to fetch token"}
    end
  end

  defp install_app(conn) do
    case conn |> app_name() |> AppServer.get() do
      {:ok, app} ->
        oauth_url = ShopifyAPI.shopify_oauth_url(app, shop_domain(conn))
        Logger.debug("redirecting to Shop oauth url: #{oauth_url}")

        conn
        |> Conn.put_resp_header("location", oauth_url)
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

  @doc """
  Returns the myshopify domain a request is about.

  Shopify identifies the shop with an `x-shopify-shop-domain` header on some requests and a
  `shop` query parameter on others, so both are checked, header first. Returns `nil` when
  neither is present.
  """
  @spec shop_domain(Plug.Conn.t()) :: String.t() | nil
  def shop_domain(conn), do: shop_domain_from_header(conn) || conn.params["shop"]

  @doc false
  defp app_name(conn), do: conn.params["app"] || List.last(conn.path_info)

  @doc """
  Checks a request's query parameters against the `hmac` parameter Shopify signed them with.

  Every parameter except `hmac` and `signature` is sorted, joined into a query string and
  hashed with the app's client secret. Returns `false` on any mismatch, including a request
  carrying no `hmac` at all.
  """
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

  defp shop_from_auth_token(%ShopifyAPI.UserToken{shop_name: myshopify_domain}),
    do: %ShopifyAPI.Shop{domain: myshopify_domain}

  defp installed_redirect_uri(%_{client_id: app_api_key}, %_{domain: myshopify_domain}) do
    %URI{
      scheme: "https",
      port: 443,
      host: myshopify_domain,
      path: "/admin/apps/#{app_api_key}"
    }
  end
end
