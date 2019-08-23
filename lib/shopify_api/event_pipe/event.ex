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
            metadata: %{},
            response: nil

  @type callback :: (ShopifyAPI.AuthToken.t(), t() -> any())

  @type t :: %__MODULE__{
          destination: String.t(),
          token: map(),
          object: any(),
          callback: nil | callback(),
          action: String.t(),
          assigns: map(),
          metadata: map(),
          response: any()
        }
end
