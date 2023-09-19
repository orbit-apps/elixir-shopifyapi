defmodule ShopifyAPI.UserToken do
  @moduledoc """
  Represents the auth token for individual users, Shopify documentation for the auth process
  is here https://shopify.dev/docs/apps/auth/oauth/getting-started#online-access-mode
  """

  @derive {Jason.Encoder,
           only: [
             :code,
             :app_name,
             :shop_name,
             :token,
             :timestamp,
             :plus,
             :scope,
             :expires_in,
             :associated_user_scope,
             :associated_user,
             :associated_user_id
           ]}
  defstruct code: "",
            app_name: "",
            shop_name: "",
            token: "",
            timestamp: 0,
            plus: false,
            scope: "",
            expires_in: 0,
            associated_user_scope: "",
            associated_user: %ShopifyAPI.AssociatedUser{},
            associated_user_id: 0

  @typedoc """
  Type that represents a Shopify Online Access Mode Auth Token with

    - app_name corresponding to %ShopifyAPI.App{name: app_name}
    - shop_name corresponding to %ShopifyAPI.Shop{domain: shop_name}
  """
  @type t :: %__MODULE__{
          code: String.t(),
          app_name: String.t(),
          shop_name: String.t(),
          token: String.t(),
          timestamp: integer(),
          plus: boolean(),
          scope: String.t(),
          expires_in: integer(),
          associated_user_scope: String.t(),
          associated_user: ShopifyAPI.AssociatedUser.t(),
          associated_user_id: integer()
        }
  @type ok_t :: {:ok, t()}
  @type key :: String.t()

  alias ShopifyAPI.App
  alias ShopifyAPI.AssociatedUser

  @spec create_key(t()) :: key()
  def create_key(token) when is_struct(token, __MODULE__),
    do: create_key(token.shop_name, token.app_name, token.associated_user_id)

  @spec create_key(String.t(), String.t(), integer()) :: key()
  def create_key(shop, app, associated_user_id), do: "#{shop}:#{app}:#{associated_user_id}"

  @spec from_auth_request(App.t(), String.t(), String.t(), map()) :: t()
  def from_auth_request(app, myshopify_domain, auth_code, attrs) when is_struct(app, App) do
    user = AssociatedUser.from_auth_request(attrs["associated_user"])

    struct(__MODULE__,
      associated_user: user,
      associated_user_id: user.id,
      associated_user_scope: attrs["associated_user_scope"],
      app_name: app.name,
      shop_name: myshopify_domain,
      code: auth_code,
      token: attrs["access_token"],
      timestamp: DateTime.to_unix(DateTime.utc_now()),
      expires_in: attrs["expires_in"],
      scope: attrs["scope"]
    )
  end
end
