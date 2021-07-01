defmodule ShopifyAPI.Router do
  use Plug.Router
  require Logger

  alias Plug.Conn
  alias ShopifyAPI.{App, AuthToken, AuthTokenServer, ConnHelpers}
  alias ShopifyAPI.Shop

  plug(:match)
  plug(:dispatch)

  get "/install/:app" do
    install_app(conn)
  end

  get "/install" do
    install_app(conn)
  end

  # Shopify Callback on App authorization
  get "/authorized/:app" do
    Logger.info("Authorized #{ConnHelpers.shop_domain(conn)}")

    if auth_code_present?(conn) do
      with {:ok, app} <- ConnHelpers.fetch_shopify_app(conn),
           true <- verify_nonce(app, conn.query_params),
           true <- ConnHelpers.verify_params_with_hmac(app, conn.query_params),
           {:ok, auth_token} <- request_auth_token(conn, app) do
        Shop.post_install(auth_token)
        AuthTokenServer.set(auth_token)

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

  defp install_app(conn) do
    conn
    |> ConnHelpers.fetch_shopify_app()
    |> case do
      {:ok, app} ->
        install_url = App.install_url(app, ConnHelpers.shop_domain(conn))

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

  defp auth_code_present?(conn), do: ConnHelpers.auth_code(conn) != nil
end
