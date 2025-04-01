defmodule ShopifyAPI.ShopifyValidationSetup do
  @rejected_hmac_keys ["hmac", :hmac, "signature", :signature]

  def params_append_hmac(%ShopifyAPI.App{} = app, %{} = params) do
    hmac =
      params
      |> Enum.reject(fn {key, _} -> Enum.member?(@rejected_hmac_keys, key) end)
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map_join("&", fn {key, value} -> to_string(key) <> "=" <> value end)
      |> ShopifyAPI.Security.base16_sha256_hmac(app.client_secret)

    Map.put(params, :hmac, hmac)
  end
end
