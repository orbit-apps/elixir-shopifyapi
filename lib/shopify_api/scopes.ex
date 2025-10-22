defmodule ShopifyAPI.Scopes do
  alias ShopifyAPI.Scope

  @spec shop(Scope.t()) :: ShopifyAPI.Shop.t()
  def shop(scope), do: Scope.shop(scope)

  @spec app(Scope.t()) :: ShopifyAPI.App.t()
  def app(scope), do: Scope.app(scope)

  @spec auth_token(Scope.t()) :: ShopifyAPI.AuthToken.t()
  def auth_token(scope), do: Scope.auth_token(scope)

  @spec user_token(Scope.t()) :: ShopifyAPI.UserToken.t() | nil
  def user_token(scope), do: Scope.user_token(scope)

  @spec myshopify_domain(Scope.t()) :: String.t()
  def myshopify_domain(scope), do: shop(scope).domain

  @spec shop_slug(Scope.t()) :: String.t()
  def shop_slug(scope), do: scope |> myshopify_domain() |> ShopifyAPI.Shop.slug_from_domain()

  @spec app_name(Scope.t()) :: String.t()
  def app_name(scope), do: Scope.app(scope).name

  @spec app_handle(Scope.t()) :: String.t()
  def app_handle(scope), do: Scope.app(scope).handle

  @doc """
  Accessor for either the User's Token (aka online token) falling back
  to the Shop's Token (aka offline token)

  ## Examples
      iex> %{user_token: %ShopifyAPI.UserToken{token: "ftw"}} |> ShopifyAPI.Scopes.access_token()
      "ftw"

      iex> %{user_token: %ShopifyAPI.UserToken{token: "wtf"}, auth_token: %ShopifyAPI.AuthToken{token: "foo"}} |> ShopifyAPI.Scopes.access_token()
      "wtf"

      iex> %{user_token: nil, auth_token: %ShopifyAPI.AuthToken{token: "foo"}} |> ShopifyAPI.Scopes.access_token()
      "foo"

      iex> %{auth_token: %ShopifyAPI.AuthToken{token: "bar"}} |> ShopifyAPI.Scopes.access_token()
      "bar"
  """
  @spec access_token(Scope.t()) :: String.t()
  def access_token(scope) do
    token =
      case user_token(scope) do
        user_token = %ShopifyAPI.UserToken{} -> user_token
        _ -> auth_token(scope)
      end

    token.token
  end
end
