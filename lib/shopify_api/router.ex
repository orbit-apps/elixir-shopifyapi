defmodule ShopifyAPI.Router do
  use Plug.Router

  alias ShopifyAPI.{ShopInstaller}

  plug(:match)
  plug(:dispatch)

  get "/install/:app" do
    ShopInstaller.initialize_installation(conn)
  end

  get "/install" do
    ShopInstaller.initialize_installation(conn)
  end

  # Shopify Callback on App authorization
  get "/authorized/:app" do
    ShopInstaller.complete_installation(conn)
  end
end
