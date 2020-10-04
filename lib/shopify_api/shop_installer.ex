defmodule ShopifyAPI.ShopInstaller do
  require Logger

  alias Plug.Conn

  alias ShopifyAPI.{App, AuthToken, AuthTokenServer, ConnHelpers}
  alias ShopifyAPI.Shop

  @spec initialize_installation(Plug.Conn.t()) :: Plug.Conn.t()
  def initialize_installation(conn) do
    conn
    |> generate_install_url_for_app()
    |> case do
      {:ok, install_url} ->
        redirect_to_shopify_installer(conn, install_url)

      {:error, res} ->
        Logger.info("#{__MODULE__} failed install with: #{res}")
        halt_install(conn)
    end
  end

  defp generate_install_url_for_app(%Plug.Conn{} = conn) do
    with {:ok, app} <- ConnHelpers.fetch_shopify_app(conn) do
      domain = ConnHelpers.shop_domain(conn)
      install_url_for_app(app, domain)
    else
      _ ->
        {:error, "unable to fetch shopify app store"}
    end
  end

  defp install_url_for_app(app, domain) do
    install_url = App.install_url(app, domain)
    {:ok, install_url}
  end

  @spec complete_installation(Plug.Conn.t()) :: {:ok, any()} | {:error, any()}
  def complete_installation(conn) do
    case authorize_shop(conn) do
      {:ok, resp} ->
        render_authenticated_response(conn)

      {:error, msg} ->
        halt_install(conn)
    end
  end

  @spec authorize_shop(Plug.Conn.t()) :: {:ok, any()} | {:error, any()}
  def authorize_shop(conn) do
    case ConnHelpers.fetch_shopify_app(conn) do
      {:ok, app} ->
        update_token_for(conn, app)

      _ ->
        Logger.debug("app #{ConnHelpers.app_name(conn)} not found")
        {:error, "unable to fetch app"}
    end
  end

  defp update_token_for(conn, app) do
    if valid_auth_request?(conn, app) do
      Logger.debug("Authorized #{ConnHelpers.shop_domain(conn)}")
      config_auth_token(conn, app)
    else
      Logger.debug("#{__MODULE__} invalid request for #{ConnHelpers.shop_domain(conn)}. halting.")
      {:error, "invalid auth request received"}
    end
  end

  defp valid_auth_request?(conn, app) do
    nonce_verified = ConnHelpers.verify_nonce(app, conn.query_params)
    params_verified = ConnHelpers.verify_params_with_hmac(app, conn.query_params)
    shop_name_verified = ConnHelpers.verify_shop_name(ShopifyAPI.ConnHelpers.shop_domain(conn))

    Logger.debug(
      "request: nonce: #{nonce_verified} params: #{params_verified} shop_name: #{
        shop_name_verified
      } #{ShopifyAPI.ConnHelpers.shop_domain(conn)}"
    )

    nonce_verified && params_verified && shop_name_verified
  end

  defp config_auth_token(conn, app) do
    with {:ok, auth_token} <- request_permanent_token(conn, app) do
      Shop.post_install(auth_token)
      AuthTokenServer.set(auth_token)
      {:ok, "authorized"}
    else
      {:error, resp} ->
        {:error, "unable to fetch auth_token #{inspect(resp)}"}
    end
  end

  defp request_permanent_token(conn, app) do
    app
    |> App.fetch_token(ConnHelpers.shop_domain(conn), ConnHelpers.auth_code(conn))
    |> case do
      {:ok, token} ->
        {:ok,
         %AuthToken{
           app_name: ConnHelpers.app_name(conn),
           shop_name: ConnHelpers.shop_domain(conn),
           code: ConnHelpers.auth_code(conn),
           timestamp: String.to_integer(conn.query_params["timestamp"]),
           token: token
         }}

      _msg ->
        {:error, "unable to fetch token"}
    end
  end

  defp render_authenticated_response(conn) do
    conn
    |> Conn.resp(200, "Authenticated.")
    |> Conn.halt()
  end

  defp redirect_to_shopify_installer(conn, url) do
    conn
    |> Conn.put_resp_header("location", url)
    |> Conn.resp(unquote(302), "You are being redirected.")
    |> Conn.halt()
  end

  defp halt_install(conn) do
    conn
    |> Conn.resp(404, "Not Found.")
    |> Conn.halt()
  end
end
