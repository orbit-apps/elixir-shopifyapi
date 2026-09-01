defmodule ShopifyAPI.Security do
  @moduledoc """
  SHA-256 HMACs in the two encodings Shopify uses to sign requests.

  Shopify picks the encoding by context, so both exist here: hex for the `hmac` query parameter
  on OAuth callbacks and app proxy requests, Base64 for the `X-Shopify-Hmac-Sha256` header on
  webhooks. `ShopifyAPI.Router` and `ShopifyAPI.Plugs.Webhook` verify incoming requests with
  these; an app rarely calls them directly.

  Both return the digest as a string. Compare digests with `Plug.Crypto.secure_compare/2`
  rather than `==` to avoid leaking timing information.
  """

  @doc """
  Returns the lowercase hex-encoded SHA-256 HMAC of `text` under `secret`.

  ## Examples

      iex> ShopifyAPI.Security.base16_sha256_hmac("shop=acme.myshopify.com", "hush")
      "06e3aa393cc9fcfb6b0bea6977dc046acbc956d8bc5bb877ee9691af2e2dbdd9"

  """
  @spec base16_sha256_hmac(iodata(), binary()) :: String.t()
  def base16_sha256_hmac(text, secret) do
    :sha256
    |> hmac(secret, text)
    |> Base.encode16()
    |> String.downcase()
  end

  @doc """
  Returns the Base64-encoded SHA-256 HMAC of `text` under `secret`.

  ## Examples

      iex> ShopifyAPI.Security.base64_sha256_hmac("shop=acme.myshopify.com", "hush")
      "BuOqOTzJ/PtrC+ppd9wEasvJVti8W7h37paRry4tvdk="

  """
  @spec base64_sha256_hmac(iodata(), binary()) :: String.t()
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
