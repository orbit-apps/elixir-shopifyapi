defmodule ShopifyAPI.ConnHelpers do
  @moduledoc false
  require Logger

  alias Plug.Conn
  alias ShopifyAPI.{App, AppServer, AuthTokenServer, Security, Shop, ShopServer}

  @shopify_shop_header "x-shopify-shop-domain"
  @shopify_topics_header "x-shopify-topic"
  @shopify_hmac_header "x-shopify-hmac-sha256"

  @doc false
  def fetch_shopify_app(conn), do: fetch_shopify_app(conn, app_name(conn))
  def fetch_shopify_app(_conn, app_name), do: AppServer.get(app_name)

  @doc false
  def fetch_shopify_shop(conn), do: fetch_shopify_shop(conn, shop_domain(conn))

  def fetch_shopify_shop(conn, shop_domain),
    do: shop_domain |> ShopServer.get() |> optionally_create_shop(conn)

  @doc false
  defp optionally_create_shop(:error, conn), do: {:ok, %Shop{domain: shop_domain(conn)}}
  defp optionally_create_shop(shop, _), do: shop

  @doc false
  def app_name(conn), do: conn.params["app"] || app_name_from_path(conn)

  def app_name_from_path(conn), do: List.last(conn.path_info)

  @doc false
  def shop_domain(conn), do: shop_domain_from_header(conn) || conn.params["shop"]

  @doc false
  def hmac_from_header(conn) do
    conn
    |> Conn.get_req_header(@shopify_hmac_header)
    |> List.first()
  end

  @doc false
  defp shop_domain_from_header(conn) do
    conn
    |> Conn.get_req_header(@shopify_shop_header)
    |> List.first()
  end

  @doc false
  def auth_code(conn), do: conn.params["code"]

  @doc false
  def assign_app(conn, app_name \\ nil) do
    case fetch_shopify_app(conn, app_name) do
      {:ok, app} ->
        Conn.assign(conn, :app, app)

      :error ->
        conn
    end
  end

  @doc false
  def assign_shop(conn, shop_domain \\ nil) do
    case fetch_shopify_shop(conn, shop_domain) do
      {:ok, shop} ->
        Conn.assign(conn, :shop, shop)

      :error ->
        conn
    end
  end

  @doc false
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

  @doc false
  def assign_event(conn) do
    with list_of_topics <- Conn.get_req_header(conn, @shopify_topics_header),
         topic <- List.first(list_of_topics) do
      Conn.assign(conn, :shopify_event, topic)
    end
  end

  @doc false
  def verify_nonce(%App{nonce: nonce}, params) do
    nonce == params["state"]
  end

  @doc false
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
