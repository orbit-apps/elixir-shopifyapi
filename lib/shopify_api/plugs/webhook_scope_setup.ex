defmodule ShopifyAPI.Plugs.WebhookScopeSetup do
  @moduledoc """
  The Webhook Scope Setup plug reads all the shopify headers and assigns
  a %Model.WebHookScope{} to the conn.

  ## Options

  - app_name: optional, the name of the app for look up in the AppServer if left blank
    it will use the Application Config or the last element of the request path.

  ## Usage

  This should be put in a pipeline afer the ensure validation plug in your router
  on your webhook endpoint.

  ```elixir
  pipeline :shopify_webhook do
    plug ShopifyAPI.Plugs.WebhookEnsureValidation
    plug ShopifyAPI.Plugs.WebhookScopeSetup
  end
  ```
  """
  require Logger

  import Plug.Conn, only: [assign: 3, get_req_header: 2]

  @shopify_topic_header "x-shopify-topic"
  @shopify_myshopify_domain_header "x-shopify-shop-domain"
  @shopify_api_version_header "x-shopify-api-version"
  @shopify_webhook_id_header "x-shopify-webhook-id"
  @shopify_event_id_header "x-shopify-event-id"

  def init(opts), do: opts

  def call(%Plug.Conn{} = conn, opts) do
    with app_name when is_binary(app_name) <- ShopifyAPI.Config.app_name(conn, opts),
         {:ok, %ShopifyAPI.App{} = app} <- ShopifyAPI.AppServer.get(app_name),
         myshopify_domain when is_binary(myshopify_domain) <- myshopify_domain(conn) do
      webhook_scope = %ShopifyAPI.Model.WebhookScope{
        shopify_api_version: shopify_api_version(conn),
        shopify_webhook_id: shopify_webhook_id(conn),
        shopify_event_id: shopify_event_id(conn),
        topic: webhook_topic(conn),
        myshopify_domain: myshopify_domain,
        app: app,
        shop: ShopifyAPI.ShopServer.find(myshopify_domain)
      }

      assign(conn, :webhook_scope, webhook_scope)
    else
      error ->
        Logger.debug("error setting up webhook scope #{inspect(error)}")
        conn
    end
  end

  @spec webhook_topic(Plug.Conn.t()) :: String.t() | nil
  def webhook_topic(%Plug.Conn{} = conn), do: get_header(conn, @shopify_topic_header)

  def myshopify_domain(%Plug.Conn{} = conn),
    do: get_header(conn, @shopify_myshopify_domain_header)

  def shopify_api_version(%Plug.Conn{} = conn), do: get_header(conn, @shopify_api_version_header)
  def shopify_webhook_id(%Plug.Conn{} = conn), do: get_header(conn, @shopify_webhook_id_header)
  def shopify_event_id(%Plug.Conn{} = conn), do: get_header(conn, @shopify_event_id_header)

  defp get_header(conn, key), do: conn |> get_req_header(key) |> List.first()
end
