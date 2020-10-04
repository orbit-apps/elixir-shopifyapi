defmodule ShopifyAPI.ConnHelpers do
  @moduledoc false
  require Logger

  alias Plug.Conn
  alias ShopifyAPI.{App, AppServer, AuthTokenServer, Security, Shop, ShopServer}

  @shopify_shop_header "x-shopify-shop-domain"
  @shopify_topics_header "x-shopify-topic"
  @shopify_hmac_header "x-shopify-hmac-sha256"

  @doc false
  @spec optionally_create_shop(:error | {:ok, Shop.t()}, any()) :: {:ok, Shop.t()}
  defp optionally_create_shop(:error, conn), do: {:ok, %Shop{domain: shop_domain(conn)}}
  defp optionally_create_shop({:ok, _} = resp, _), do: resp

  @doc false
  def hmac_from_header(conn) do
    conn
    |> Conn.get_req_header(@shopify_hmac_header)
    |> List.first()
  end

  @doc false
  def auth_code(conn), do: conn.params["code"]

  @doc false
  def app_name(conn), do: conn.params["app"] || app_name_from_path(conn)

  @doc false
  def app_name_from_path(conn), do: List.last(conn.path_info)

  @doc false
  def fetch_shopify_app(conn), do: conn |> app_name() |> AppServer.get()

  @doc false
  def assign_app(conn, name \\ nil)
  def assign_app(conn, %App{} = app), do: Conn.assign(conn, :app, app)

  def assign_app(conn, name) do
    case AppServer.get(name || app_name(conn)) do
      {:ok, app} ->
        Conn.assign(conn, :app, app)

      _ ->
        conn
    end
  end

  @doc false
  defp shop_domain_from_header(conn) do
    conn
    |> Conn.get_req_header(@shopify_shop_header)
    |> List.first()
  end

  @doc false
  def shop_domain(conn), do: shop_domain_from_header(conn) || conn.params["shop"]

  @doc false
  @spec fetch_shopify_shop(any(), String.t()) :: {:ok, Shop.t()}
  defp fetch_shopify_shop(conn, domain),
    do: domain |> ShopServer.get() |> optionally_create_shop(conn)

  @doc false
  def assign_shop(conn, domain \\ nil) do
    {:ok, shop} = fetch_shopify_shop(conn, domain || shop_domain(conn))
    Conn.assign(conn, :shop, shop)
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
  @spec verify_params_with_hmac(App.t(), map()) :: boolean()
  def verify_params_with_hmac(%App{client_secret: secret}, params) do
    hmac = build_hmac_from_params(params, secret)
    params["hmac"] == hmac
  end

  def build_hmac_from_params(params, secret) do
    params
    |> Enum.reject(fn {key, _} -> "#{key}" == "hmac" or "#{key}" == "signature" end)
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.map(fn {key, value} -> "#{key}" <> "=" <> "#{value}" end)
    |> Enum.join("&")
    |> Security.base16_sha256_hmac(secret)
  end

  @doc false

  def verify_shop_name(name) do
    String.match?("#{name}", ~r/^[a-zA-Z0-9][a-zA-Z0-9\-]*\.myshopify\.com[\/]?/)
  end
end
