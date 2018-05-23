defmodule ShopifyApi.AuthToken do
  defstruct code: "",
            app_name: "",
            shop_name: "",
            token: "",
            timestamp: 0

  @typedoc """
      Type that represents a Shopify Auth Token with

        - app_name corresponding to %ShopifyApi.App{name: app_name}
        - shop_name corresponding to %ShopifyApi.Shop{domain: shop_name}
  """
  @type t :: %__MODULE__{
          code: String.t(),
          app_name: String.t(),
          shop_name: String.t(),
          token: String.t(),
          timestamp: 0
        }
end
