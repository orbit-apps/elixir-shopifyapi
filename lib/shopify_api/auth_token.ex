defmodule ShopifyAPI.AuthToken do
  require Logger

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
  def new(%App{} = app, myshopify_domain, auth_code, token) do
    %__MODULE__{
      app_name: app.name,
      shop_name: myshopify_domain,
      code: auth_code,
      token: token
    }
  end

  @spec from_auth_request(App.t(), String.t(), String.t(), map()) :: t()
  def from_auth_request(%App{} = app, myshopify_domain, code \\ "", %{} = attrs),
    do: new(app, myshopify_domain, code, attrs["access_token"])

  @spec get_offline_token(App.t(), String.t(), String.t()) ::
          ok_t() | {:error, :failed_fetching_online_token}
  def get_offline_token(%App{} = app, myshopify_domain, token) do
    case ShopifyAPI.AuthTokenServer.get(myshopify_domain, app.name) do
      {:ok, _} = resp -> resp
      _ -> mutexed_get_offline_token(app, myshopify_domain, token)
    end
  end

  defp mutexed_get_offline_token(app, myshopify_domain, token) do
    mutex_key = {app.name, myshopify_domain}

    Mutex.with_lock(ShopifyAPI.OfflineToken, mutex_key, fn ->
      # Try fetching a valid token from cache, a new one may have been put in here since the
      # first call
      case ShopifyAPI.AuthTokenServer.get(myshopify_domain, app.name) do
        {:ok, _} = resp -> resp
        _ -> request_offline_token(app, myshopify_domain, token)
      end
    end)
  end

  defp request_offline_token(app, myshopify_domain, token) do
    case ShopifyAPI.AuthRequest.request_offline_access_token(app, myshopify_domain, token) do
      {:ok, token} ->
        Task.async(fn -> ShopifyAPI.Shop.post_login(token) end)
        {:ok, token}

      error ->
        error
    end
  end
end
