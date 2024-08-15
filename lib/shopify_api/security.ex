defmodule ShopifyAPI.Security do
  require Logger

  def base16_sha256_hmac(text, secret) do
    Logger.warning("Hmac passed into ShopifyAPI.Security is #{text}")

    :sha256
    |> hmac(secret, text)
    |> Base.encode16()
    |> String.downcase()
  end

  def base64_sha256_hmac(text, secret) do
    :sha256
    |> hmac(secret, text)
    |> Base.encode64()
  end

  # TODO: remove when we require OTP 22
  if System.otp_release() >= "22" do
    defp hmac(digest, key, data), do: :crypto.mac(:hmac, digest, key, data)
  else
    defp hmac(digest, key, data), do: :crypto.hmac(digest, key, data)
  end
end
