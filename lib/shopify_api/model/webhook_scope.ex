defmodule ShopifyAPI.Model.WebhookScope do
  @type t() :: %__MODULE__{
          shopify_api_version: String.t(),
          shopify_webhook_id: String.t(),
          # Using the Shopify CLI the event id can be unset
          shopify_event_id: String.t() | nil,
          topic: String.t(),
          myshopify_domain: String.t(),
          app: ShopifyAPI.App.t(),
          shop: ShopifyAPI.Shop.t()
        }

  defstruct [
    :shopify_api_version,
    :shopify_webhook_id,
    :shopify_event_id,
    :topic,
    :myshopify_domain,
    :app,
    :shop
  ]
end
