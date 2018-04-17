# TODO has multiple auth structs
defmodule ShopifyApi.Shop do
  defstruct client_id: "",
            client_secret: "",
            code: "",
            hmac: "",
            domain: "",
            auth_redirect_uri: "",
            nonce: "",
            timestamp: 0,
            access_token: ""
end
