defmodule ShopifyApi.EventPipe.Event do
  defstruct destination: :nowhere,
            token: %{},
            object: nil,
            callback: nil,
            action: :none
end
