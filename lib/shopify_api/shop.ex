# TODO has multiple auth structs
defmodule ShopifyApi.Shop do
  defstruct domain: ""

  @typedoc """
      Type that represents a Shopify Shop with

        - domain corrisponding to the full URL for the shop
  """
  @type t :: %__MODULE__{
          domain: String.t()
        }
end
