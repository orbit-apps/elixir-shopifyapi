defmodule ShopifyAPI.EventPipe.Event do
  @derive Jason.Encoder
  defstruct destination: "nowhere",
            app: %{},
            shop: %{},
            token: %{},
            object: nil,
            callback: nil,
            action: "none",
            assigns: %{},
            response: nil

  @type callback :: (ShopifyAPI.AuthToken.t(), t() -> any())

  @type t :: %__MODULE__{
          destination: String.t(),
          token: map(),
          object: any(),
          callback: nil | callback(),
          action: String.t(),
          assigns: map(),
          response: any()
        }
end
