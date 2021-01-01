defmodule ShopifyAPI.AuthToken do
  @derive {Jason.Encoder,
           only: [:code, :app_name, :shop_name, :token, :timestamp, :plus, :app_data]}
  defstruct code: "",
            app_name: "",
            shop_name: "",
            token: "",
            timestamp: 0,
            plus: false,
            app_data: %{}

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
          plus: boolean(),
          app_data: map()
        }

  @spec create_key(t()) :: String.t()
  def create_key(%__MODULE__{shop_name: shop, app_name: app}), do: create_key(shop, app)

  @spec create_key(String.t(), String.t()) :: String.t()
  def create_key(shop, app), do: "#{shop}:#{app}"
end
