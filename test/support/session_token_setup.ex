defmodule ShopifyAPI.SessionTokenSetup do
  import ShopifyAPI.Factory

  # Each builder caches its token under the context's `:app` when one is given, and under the
  # factory app otherwise.

  def offline_token(%{shop: %ShopifyAPI.Shop{} = shop} = context) do
    token = build(:auth_token, %{shop_name: shop.domain, app_name: app_name(context)})
    ShopifyAPI.AuthTokenServer.set(token)
    [offline_token: token]
  end

  def online_token(%{shop: %ShopifyAPI.Shop{} = shop} = context) do
    token = %{build(:user_token, %{shop_name: shop.domain}) | app_name: app_name(context)}
    ShopifyAPI.UserTokenServer.set(token)
    [online_token: token]
  end

  # Signs with the context's `:secret` when one is given, and the app's client secret otherwise.
  def jwt_session_token(%{app: app, shop: shop, online_token: online_token} = context) do
    payload = %{
      "aud" => app.client_id,
      "dest" => "http://#{shop.domain}",
      "sub" => "#{online_token.associated_user_id}"
    }

    jwk = JOSE.JWK.from_oct(Map.get(context, :secret, app.client_secret))
    {_, jwt} = jwk |> JOSE.JWT.sign(%{"alg" => "HS256"}, payload) |> JOSE.JWS.compact()

    [jwt_session_token: jwt]
  end

  defp app_name(%{app: %ShopifyAPI.App{name: name}}), do: name
  defp app_name(_context), do: shopify_app_name()
end
