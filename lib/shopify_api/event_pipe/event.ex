defmodule ShopifyApi.EventPipe.Event do
  defstruct destination: :nowhere,
            token: %{},
            object: nil,
            callback: nil,
            action: :none

  @type t :: %__MODULE__{
          destination: atom(),
          token: map(),
          object: any(),
          callback: any(),
          action: atom()
        }
end
