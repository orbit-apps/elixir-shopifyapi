defmodule ShopifyApi.Security do
  def sha256_hmac(text, secret) do
    :crypto.hmac(:sha256, secret, text)
    |> Base.encode16()
    |> String.downcase()
  end
end
