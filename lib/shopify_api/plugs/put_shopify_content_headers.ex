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
    |> put_resp_header("x-frame-options", "ALLOW-FROM https://" <> myshopify_domain(conn))
    |> put_resp_header(
      "content-security-policy",
      "frame-ancestors https://" <> myshopify_domain(conn) <> " https://admin.shopify.com;"
    )
  end

  defp myshopify_domain(%{assigns: %{shop: %{domain: domain}}}), do: domain
end
