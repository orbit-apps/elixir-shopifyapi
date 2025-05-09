defprotocol ShopifyAPI.Scope do
  @fallback_to_any true

  @spec auth_token(__MODULE__.t()) :: ShopifyAPI.AuthToken.t()
  def auth_token(scope)

  @spec user_token(__MODULE__.t()) :: ShopifyAPI.UserToken.t() | nil
  def user_token(scope)

  @spec shop(__MODULE__.t()) :: ShopifyAPI.Shop.t()
  def shop(scope)

  @spec app(__MODULE__.t()) :: ShopifyAPI.App.t()
  def app(scope)
end

defimpl ShopifyAPI.Scope, for: Any do
  def shop(%{shop: shop}), do: shop

  def app(%{app: app}), do: app

  def auth_token(%{auth_token: auth_token}), do: auth_token

  def user_token(%{user_token: %ShopifyAPI.UserToken{} = user_token}), do: user_token
  def user_token(_), do: nil
end
