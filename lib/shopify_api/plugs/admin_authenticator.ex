defmodule ShopifyAPI.Plugs.AdminAuthenticator do
  @moduledoc """
  The ShopifyAPI.Plugs.AdminAuthenticator plug allows for easy admin authentication. The plug
  when included in your route will verify Shopify signatures, that are added to the iframe call
  on admin page load, and set a session cookie for the duration of the session.

  NOTE: This plug only does authentication for the initial iframe load, it will check for the
  presents of the hmac and do the validation, if no hmac is present it will just continue.

  The plug will assign the Shop, App and AuthToken to the Conn for easy access in your
  admin controller when the a valid hmac is provided.

  When no HMAC is provided, the plug passes through without assigning the Shop, App and AuthToken.
  Shopify expects this behaviour and has started rejecting new apps that do not behave this way.

  Make sure to include the App name in the path, in our example it is included directly in the
  path `"/shop-admin/:app"`. Or include the :app_name in the mount parameters.

  ## Example Usage
  ```elixir
  # Router
  pipeline :shop_admin do
    plug ShopifyAPI.Plugs.AdminAuthenticator
  end

  scope "/shop-admin/:app", YourAppWeb do
    pipe_through :browser
    pipe_through :shop_admin
    get "/", SomeAdminController, :index
  end
  ```
  """
  require Logger

  alias Plug.Conn

  alias ShopifyAPI.JWTSessionToken

  @defaults [shopify_mount_path: "/shop"]

  def init(opts), do: Keyword.merge(opts, @defaults)

  def call(conn, options) do
    if should_do_authentication?(conn) do
      do_authentication(conn, options)
    else
      conn
    end
  end

  defp do_authentication(conn, _options) do
    token = conn.params["id_token"]

    with {:ok, app} <- JWTSessionToken.app(token),
         {true, jwt, _jws} <- JWTSessionToken.verify(token, app.client_secret),
         :ok <- validate_hmac(app, conn.query_params),
         {:ok, myshopify_domain} <- JWTSessionToken.myshopify_domain(jwt),
         {:ok, shop} <- ShopifyAPI.ShopServer.get_or_create(myshopify_domain, true),
         {:ok, auth_token} <- JWTSessionToken.get_offline_token(jwt, token),
         {:ok, user_token} <- JWTSessionToken.get_user_token(jwt, token) do
      conn
      |> assign_app(app)
      |> assign_shop(shop)
      |> assign_auth_token(auth_token)
      |> assign_user_token(user_token)
    else
      {:error, :invalid_hmac} ->
        Logger.info("#{__MODULE__} failed hmac validation")

        conn
        |> Conn.resp(401, "Not Authorized.")
        |> Conn.halt()

      _ ->
        conn
    end
  end

  defp should_do_authentication?(conn), do: has_hmac(conn.query_params) == :ok

  defp assign_app(conn, app), do: Conn.assign(conn, :app, app)
  defp assign_shop(conn, shop), do: Conn.assign(conn, :shop, shop)
  defp assign_auth_token(conn, auth_token), do: Conn.assign(conn, :auth_token, auth_token)
  defp assign_user_token(conn, user_token), do: Conn.assign(conn, :user_token, user_token)

  defp has_hmac(%{"hmac" => hmac}) when is_binary(hmac), do: :ok
  defp has_hmac(_params), do: {:error, :no_hmac}

  defp validate_hmac(%ShopifyAPI.App{client_secret: secret}, params) do
    request_hmac = params["hmac"]

    params
    |> Enum.reject(fn {key, _} -> key == "hmac" or key == "signature" end)
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.map_join("&", fn {key, value} -> key <> "=" <> value end)
    |> ShopifyAPI.Security.base16_sha256_hmac(secret)
    |> then(fn
      ^request_hmac -> :ok
      _ -> {:error, :invalid_hmac}
    end)
  end
end
