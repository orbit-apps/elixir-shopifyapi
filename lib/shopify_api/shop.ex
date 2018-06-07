# TODO has multiple auth structs
defmodule ShopifyAPI.Shop do
  defstruct domain: ""

  @typedoc """
      Type that represents a Shopify Shop with

        - domain corresponding to the full URL for the shop
  """
  @type t :: %__MODULE__{
          domain: String.t()
        }
end
