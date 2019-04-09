defmodule ShopifyAPI.EventPipe.Event do
  defstruct destination: :nowhere,
            app: %{},
            shop: %{},
            token: %{},
            object: nil,
            callback: nil,
            action: :none,
            assigns: %{},
            response: nil

  @type callback :: (ShopifyAPI.AuthToken.t(), t() -> any())

  @type t :: %__MODULE__{
          destination: atom(),
          token: map(),
          object: any(),
          callback: nil | callback(),
          action: atom() | String.t(),
          assigns: map(),
          response: any()
        }
end
