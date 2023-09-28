defmodule ShopifyAPI.Plugs.AuthShopSessionToken do
  @moduledoc """
  A Plug to handle authenticating the Shop Admin JWT from Shopify.

  Options
    - use_online_tokens (boolean) default: false

  ## Example Installations

  Add this plug in a pipeline for your Shop Admin API.

  ```elixir
  pipeline :shop_admin_api do
    plug :accepts, ["json"]
    plug ShopifyAPI.Plugs.AuthShopSessionToken
  end
  ```

  If you want to use online tokens (per user tokens), you will need to enable it here

  ```elixir
  pipeline :shop_admin_api do
    plug :accepts, ["json"]
    plug ShopifyAPI.Plugs.AuthShopSessionToken, use_online_tokens: true
  end
  ```
  """

  import Plug.Conn

  require Logger

  alias ShopifyAPI.AppServer
  alias ShopifyAPI.AuthTokenServer
  alias ShopifyAPI.ShopServer
  alias ShopifyAPI.UserTokenServer

  @defaults [use_online_tokens: false]
  @client_redirect_header "x-shopify-api-request-failure-reauthorize-url"

  def init(opts), do: Keyword.merge(@defaults, opts)

  def call(conn, options) do
    use_online_tokens = options[:use_online_tokens]

    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, app} <- get_app_from_token(token),
         {true, jwt, _jws} <- verify_token(token, app.client_secret),
         {:ok, myshopify_domain} <- get_my_shopify_domain_from_jwt(jwt),
         {:ok, user_id} <- get_user_from_jwt(jwt),
         {:ok, shop} <- ShopServer.get(myshopify_domain),
         {:ok, auth_token} <- AuthTokenServer.get(myshopify_domain, app.name),
         {:ok, user_token} <- get_user_token(myshopify_domain, app, user_id, use_online_tokens) do
      conn
      |> assign(:app, app)
      |> assign(:shop, shop)
      |> assign(:auth_token, auth_token)
      |> assign(:user_id, user_id)
      |> assign(:user_token, user_token)
    else
      {:error, :user_token_invalid, redirect_url} ->
        Logger.debug("Found invalid user token adding redirect header to #{redirect_url}")

        conn
        |> resp(403, "Not Authorized.")
        |> put_resp_header(@client_redirect_header, redirect_url)
        |> halt()

      error ->
        Logger.debug("Could not authenticate shop #{inspect(error)}")

        conn
        |> resp(401, "Not Authorized.")
        |> halt()
    end
  end

  defp verify_token(token, client_secret) do
    jwk = JOSE.JWK.from_oct(client_secret)
    JOSE.JWT.verify_strict(jwk, ["HS256"], token)
  end

  defp get_user_token(_domain, _app, _user_id, false), do: {:ok, nil}

  defp get_user_token(domain, app, id, true) do
    case UserTokenServer.get_valid(domain, app.name, id) do
      {:ok, token} ->
        {:ok, token}

      {:error, _} = resp ->
        Logger.debug("Get user token failed with #{inspect(resp)}")
        oauth_url = ShopifyAPI.shopify_oauth_url(app, domain, use_user_tokens: true)
        {:error, :user_token_invalid, oauth_url}
    end
  end

  defp get_app_from_token(token) do
    with %JOSE.JWT{fields: %{"aud" => client_id}} <- JOSE.JWT.peek_payload(token),
         {:ok, app} <- AppServer.get_by_client_id(client_id) do
      {:ok, app}
    else
      _ -> {:error, "Audience claim is not a valid App clientId."}
    end
  end

  defp get_my_shopify_domain_from_jwt(%JOSE.JWT{fields: %{"dest" => shop_url}}) do
    shop_url
    |> URI.parse()
    |> Map.get(:host)
    |> case do
      shop_name when is_binary(shop_name) -> {:ok, shop_name}
      _ -> {:error, "Shop name not found"}
    end
  end

  defp get_user_from_jwt(%JOSE.JWT{fields: %{"sub" => user_id}}),
    do: {:ok, String.to_integer(user_id)}
end
