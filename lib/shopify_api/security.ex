defmodule ShopifyAPI.Security do
  @moduledoc """
  Verifies the SHA-256 HMACs Shopify signs requests with.

  Shopify picks the encoding by context: hex for the `hmac` query parameter on OAuth callbacks,
  admin loads and app proxy requests, Base64 for the `X-Shopify-Hmac-Sha256` header on
  webhooks. `valid_params_hmac?/2` and `valid_body_hmac?/3` check each against an app's
  `ShopifyAPI.App.verification_secrets/1`, so a request signed with either secret of a rotation
  passes and one signed with a blank secret never does. `ShopifyAPI.Router`,
  `ShopifyAPI.Plugs.AdminAuthenticator` and `ShopifyAPI.Plugs.Webhook` verify requests with
  them.

  `base16_sha256_hmac/2` and `base64_sha256_hmac/2` compute a digest under a single secret.
  Compare digests with `Plug.Crypto.secure_compare/2` rather than `==` to avoid leaking timing
  information.
  """

  alias ShopifyAPI.App

  @doc """
  Checks query parameters against the hex `hmac` parameter Shopify signed them with.

  Every parameter except `hmac` and `signature` is sorted and joined into a query string, which
  must hash to `hmac` under one of the app's verification secrets. Returns `false` for a request
  carrying no `hmac` and for an app with no usable secret.

  ## Examples

      iex> params = %{
      ...>   "shop" => "acme.myshopify.com",
      ...>   "hmac" => "06e3aa393cc9fcfb6b0bea6977dc046acbc956d8bc5bb877ee9691af2e2dbdd9"
      ...> }
      iex> ShopifyAPI.Security.valid_params_hmac?(%ShopifyAPI.App{client_secret: "hush"}, params)
      true
      iex> app = %ShopifyAPI.App{client_secret: "new", client_secret_secondary: "hush"}
      iex> ShopifyAPI.Security.valid_params_hmac?(app, params)
      true
      iex> ShopifyAPI.Security.valid_params_hmac?(%ShopifyAPI.App{client_secret: "new"}, params)
      false

  """
  @spec valid_params_hmac?(App.t(), map()) :: boolean()
  def valid_params_hmac?(%App{} = app, %{"hmac" => hmac} = params) when is_binary(hmac) do
    message =
      params
      |> Enum.reject(fn {key, _} -> key == "hmac" or key == "signature" end)
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map_join("&", fn {key, value} -> key <> "=" <> value end)

    signed_with_any?(app, hmac, &base16_sha256_hmac(message, &1))
  end

  def valid_params_hmac?(%App{}, _params), do: false

  @doc """
  Checks a raw request body against the Base64 HMAC Shopify sent with it.

  `hmac` is the `X-Shopify-Hmac-Sha256` header value, and `body` must be the bytes as received,
  before any JSON parsing. Returns `false` for an app with no usable secret.

  ## Examples

      iex> body = "shop=acme.myshopify.com"
      iex> hmac = "BuOqOTzJ/PtrC+ppd9wEasvJVti8W7h37paRry4tvdk="
      iex> ShopifyAPI.Security.valid_body_hmac?(%ShopifyAPI.App{client_secret: "hush"}, body, hmac)
      true
      iex> ShopifyAPI.Security.valid_body_hmac?(%ShopifyAPI.App{client_secret: "new"}, body, hmac)
      false

  """
  @spec valid_body_hmac?(App.t(), iodata(), String.t()) :: boolean()
  def valid_body_hmac?(%App{} = app, body, hmac) when is_binary(hmac),
    do: signed_with_any?(app, hmac, &base64_sha256_hmac(body, &1))

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

  defp signed_with_any?(app, hmac, digest_fun) do
    app
    |> App.verification_secrets()
    |> Enum.any?(&Plug.Crypto.secure_compare(hmac, digest_fun.(&1)))
  end

  # TODO: remove when we require OTP 22
  if System.otp_release() >= "22" do
    defp hmac(digest, key, data), do: :crypto.mac(:hmac, digest, key, data)
  else
    defp hmac(digest, key, data), do: :crypto.hmac(digest, key, data)
  end
end
