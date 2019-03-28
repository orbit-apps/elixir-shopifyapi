defmodule ShopifyAPI.ConnHelpers do
  require Logger

  alias Plug.Conn
  alias ShopifyAPI.{App, AppServer, AuthToken, AuthTokenServer, Security, Shop, ShopServer}

  def fetch_shopify_app(conn) do
    conn
    |> app_name()
    |> AppServer.get()
  end

  def fetch_shopify_shop(conn) do
    conn
    |> shop_domain()
    |> ShopServer.get()
    |> optionally_create_shop()
  end

  @doc false
  defp optionally_create_shop(:error), do: {:ok, %Shop{domain: shop_domain(conn)}}
  defp optionally_create_shop(shop), do: shop

  def app_name(conn) do
    conn.params["app"] || List.last(conn.path_info)
  end

  def shop_domain(conn) do
    conn |> Conn.get_req_header("x-shopify-shop-domain") |> List.first() || conn.params["shop"]
  end

  def auth_code(conn) do
    conn.params["code"]
  end

  def assign_app(conn) do
    case fetch_shopify_app(conn) do
      {:ok, app} -> Conn.assign(conn, :app, app)
      :error -> conn
    end
  end

  def assign_shop(conn) do
    case fetch_shopify_shop(conn) do
      {:ok, shop} -> Conn.assign(conn, :shop, shop)
      :error -> conn
    end
  end

  def assign_auth_token(conn) do
    with shop <- conn.assigns.shop,
         shop_domain <- Map.get(shop, :domain),
         app <- conn.assigns.app,
         app_name <- Map.get(app, :name),
         {:ok, auth_token} <- AuthTokenServer.get(shop_domain, app_name) do
      Conn.assign(conn, :auth_token, auth_token)
    else
      res ->
        Logger.info("#{__MODULE__} failed to find authtoken with: #{inspect(res)}")
        conn
    end
  end

  def assign_event(conn) do
    with list_of_topics <- Conn.get_req_header(conn, "x-shopify-topic"),
         topic <- List.first(list_of_topics) do
      Conn.assign(conn, :shopify_event, topic)
    end
  end

  def verify_nonce(%App{nonce: nonce}, params) do
    nonce == params["state"]
  end

  def verify_params_with_hmac(%App{client_secret: secret}, params) do
    params["hmac"] ==
      params
      |> Enum.reject(fn {key, _} -> key == "hmac" or key == "signature" end)
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map(fn {key, value} -> key <> "=" <> value end)
      |> Enum.join("&")
      |> Security.base16_sha256_hmac(secret)
  end
end
