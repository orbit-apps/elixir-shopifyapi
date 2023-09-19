defmodule ShopifyAPI.AuthToken do
  @derive {Jason.Encoder, only: [:code, :app_name, :shop_name, :token, :timestamp, :plus]}
  defstruct code: "",
            app_name: "",
            shop_name: "",
            token: "",
            timestamp: 0,
            plus: false

  @typedoc """
      Type that represents a Shopify Auth Token with

        - app_name corresponding to %ShopifyAPI.App{name: app_name}
        - shop_name corresponding to %ShopifyAPI.Shop{domain: shop_name}
  """
  @type t :: %__MODULE__{
          code: String.t(),
          app_name: String.t(),
          shop_name: String.t(),
          token: String.t(),
          timestamp: 0,
          plus: boolean()
        }
  @type ok_t :: {:ok, t()}

  alias ShopifyAPI.App

  @spec create_key(t()) :: String.t()
  def create_key(%__MODULE__{shop_name: shop, app_name: app}), do: create_key(shop, app)

  @spec create_key(String.t(), String.t()) :: String.t()
  def create_key(shop, app), do: "#{shop}:#{app}"

  @spec new(App.t(), String.t(), String.t(), String.t()) :: t()
  def new(app, myshopify_domain, auth_code, token) do
    %__MODULE__{
      app_name: app.name,
      shop_name: myshopify_domain,
      code: auth_code,
      token: token
    }
  end
end
