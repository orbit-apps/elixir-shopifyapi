defmodule ShopifyAPI.EventPipe.Event do
  defstruct destination: :nowhere,
            app: %{},
            shop: %{},
            token: %{},
            object: nil,
            callback: nil,
            action: :none,
            assigns: %{}

  @type t :: %__MODULE__{
          destination: atom(),
          token: map(),
          object: any(),
          callback: any(),
          action: atom(),
          assigns: map()
        }
end
