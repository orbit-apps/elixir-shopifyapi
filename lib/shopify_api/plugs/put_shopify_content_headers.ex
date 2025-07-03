defmodule ShopifyAPI.Plugs.PutShopifyContentHeaders do
  @moduledoc """
  A Plug to handle setting the content security and frame ancestors headers for Shop Admin.

  ## Example Installations

  Add this plug in a pipeline for your Shop Admin after the AdminAuthenticator plug.

  ```elixir
  pipeline :shop_admin do
    plug ShopifyAPI.Plugs.AdminAuthenticator, shopify_mount_path: "/shop"
    plug ShopifyAPI.Plugs.PutShopifyContentHeaders
  end
  ```
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _options) do
    conn
    |> put_resp_header("x-frame-options", "ALLOW-FROM " <> myshopify_domain_url(conn))
    |> put_resp_header(
      "content-security-policy",
      "frame-ancestors " <> myshopify_domain_url(conn) <> " https://admin.shopify.com;"
    )
  end

  defp myshopify_domain_url(conn) do
    case conn do
      %{assigns: %{shop: %{domain: domain}}} -> "https://" <> domain
      %{params: %{"shop" => domain}} -> "https://" <> domain
      _ -> ""
    end
  end
end
