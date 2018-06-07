defmodule ShopifyAPI.Security do
  def base16_sha256_hmac(text, secret) do
    :crypto.hmac(:sha256, secret, text)
    |> Base.encode16()
    |> String.downcase()
  end

  def base64_sha256_hmac(text, secret) do
    :crypto.hmac(:sha256, secret, text)
    |> Base.encode64()
  end
end
