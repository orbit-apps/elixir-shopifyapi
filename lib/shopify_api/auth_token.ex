defmodule ShopifyAPI.AuthToken do
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
          timestamp: 0,
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

defimpl ShopifyAPI.Scope, for: ShopifyAPI.AuthToken do
  def shop(auth_token) do
    case ShopifyAPI.ShopServer.get(auth_token.shop_name) do
      {:ok, shop} ->
        shop

      _ ->
        raise "Failed to find Shop for Scope out of AuthToken #{auth_token.shop_name} in ShopServer"
    end
  end

  def app(auth_token) do
    case ShopifyAPI.AppServer.get(auth_token.app_name) do
      {:ok, app} ->
        app

      _ ->
        raise "Failed to find App for Scope out of AuthToken #{auth_token.app_name} in AppServer"
    end
  end

  def auth_token(auth_token), do: auth_token

  def user_token(_auth_token), do: nil
end
