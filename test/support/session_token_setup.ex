defmodule ShopifyAPI.SessionTokenSetup do
  import ShopifyAPI.Factory

  def offline_token(%{shop: %ShopifyAPI.Shop{} = shop}) do
    token = build(:auth_token, %{shop_name: shop.domain})
    ShopifyAPI.AuthTokenServer.set(token)
    [offline_token: token]
  end

  def online_token(%{shop: %ShopifyAPI.Shop{} = shop}) do
    token = build(:user_token, %{shop_name: shop.domain})
    ShopifyAPI.UserTokenServer.set(token)
    [online_token: token]
  end

  def jwt_session_token(%{app: app, shop: shop, online_token: online_token}) do
    payload = %{
      "aud" => app.client_id,
      "dest" => "http://#{shop.domain}",
      "sub" => "#{online_token.associated_user_id}"
    }

    jwk = JOSE.JWK.from_oct(app.client_secret)
    {_, jwt} = jwk |> JOSE.JWT.sign(%{"alg" => "HS256"}, payload) |> JOSE.JWS.compact()

    [jwt_session_token: jwt]
  end
end
