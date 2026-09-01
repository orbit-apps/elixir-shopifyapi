defmodule ShopifyAPI.AuthToken do
  @moduledoc """
  An offline access token, authorizing an app to act on a shop's behalf.

  Offline tokens belong to the app rather than to a user, which makes them what REST and
  GraphQL calls authenticate with. They are obtained during installation and cached by
  `ShopifyAPI.AuthTokenServer`, which is also where the storage callbacks that outlive a
  restart are configured.

  This struct models a *non-expiring* offline token, so it carries no expiry or refresh
  token.

  The online, per-user counterpart is `ShopifyAPI.UserToken`. Shopify covers both in
  [Access tokens](https://shopify.dev/docs/apps/build/authentication-authorization/access-tokens).
  """

  @derive {Jason.Encoder, only: [:code, :app_name, :shop_name, :token, :timestamp, :plus]}
  defstruct code: "",
            app_name: "",
            shop_name: "",
            token: "",
            timestamp: 0,
            plus: false

  @typedoc """
      Type that represents a Shopify Auth Token with

        - app_name corresponding to %ShopifyAPI.App{name: app_name}
        - shop_name corresponding to %ShopifyAPI.Shop{domain: shop_name}
  """
  @type t :: %__MODULE__{
          code: String.t(),
          app_name: String.t(),
          shop_name: String.t(),
          token: String.t(),
          timestamp: integer(),
          plus: boolean()
        }
  @type ok_t :: {:ok, t()}

  alias ShopifyAPI.App

  @spec create_key(t()) :: String.t()
  def create_key(%__MODULE__{shop_name: shop, app_name: app}), do: create_key(shop, app)

  @spec create_key(String.t(), String.t()) :: String.t()
  def create_key(shop, app), do: "#{shop}:#{app}"

  @spec new(App.t(), String.t(), String.t(), String.t()) :: t()
  def new(app, myshopify_domain, auth_code, token) do
    %__MODULE__{
      app_name: app.name,
      shop_name: myshopify_domain,
      code: auth_code,
      token: token
    }
  end

  @spec from_auth_request(App.t(), String.t(), String.t(), map()) :: t()
  def from_auth_request(app, myshopify_domain, code \\ "", attrs) when is_struct(app, App) do
    new(app, myshopify_domain, code, attrs["access_token"])
  end
end
