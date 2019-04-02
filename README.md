# ShopifyAPI and Plug.ShopifyAPI

- [Installation](#installation)
- [Installing this app in a Shop](#installing-this-app-in-a-shop)
- [Configuration](#configuration)
- [Webhooks](#webhooks)

## Installation

The package can be installed by adding `shopify_api` to your list of dependencies in `mix.exs`.

```elixir
def deps do
  [
    {:shopify_api, github: "pixelunion/elixir-shopifyapi", tag: "v0.2.5"}
  ]
end
```

Add it to your phoenix routes.

```elixir
scope "/shop" do
  forward("/", ShopifyAPI.Router)
end
```

If you want to be able to handle webhooks you need to add this to your endpoint before the parsers section
```elixir
plug(ShopifyAPI.Plugs.Webhook, mount: "/shop/webhooks")
```

If you want persisted Apps, Shops, and Tokens add configuration to your functions.
```elixir
config :shopify_api, ShopifyAPI.AuthTokenServer,
  initializer: {MyApp.AuthToken, :init, []},
  persistance: {MyApp.AuthToken, :save, []}
config :shopify_api, ShopifyAPI.AppServer,
  initializer: {MyApp.ShopifyApp, :init, []},
  persistance: {MyApp.ShopifyApp, :save, []}
config :shopify_api, ShopifyAPI.ShopServer,
  initializer: {MyApp.Shop, :init, []},
  persistance: {MyApp.Shop, :save, []}
```

Optional, add graphiql to your phoenix routes
```elixir
if Mix.env == :dev do
  forward(
    "/graphiql",
    to: Absinthe.Plug.GraphiQL,
    schema: GraphQL.Config.Schema,
    interface: :playground
  )
end
```

## Installing this app in a Shop

1. Start something like ngrok
2. Configure your app to allow your ngrok url as one of the redirect_urls
3. Point your browser to `http://localhost:4000/shop/install?shop=your-shop.myshopify.com&app=yourapp` and it should prompt you to login and authorize it.


## Configuration

There is a GraphQL interface to get and update configuration, this is the recommended way of pushing configuration in to your server.

### Shops

example fetch:
```bash
curl \
  -X POST \
  -H "Content-Type: application/json" \
  --data '{"query": "{ allShops { domain } }"}' \
http://localhost:4000/shop/graphql/config
```

example set:
```bash
curl \
  -X POST \
  -H "Content-Type: application/json" \
  --data '{"query": "mutation M { updateShop(domain: \"<STORE-DOMAIN>\",) { domain } }" }' \
http://localhost:4000/shop/graphql/config
```

### Apps

example fetch:
```bash
curl \
  -X POST \
  -H "Content-Type: application/json" \
  --data '{"query": "{ allApps { authRedirectUri, clientId, clientSecret, name, nonce, scope } }"}' \
http://localhost:4000/shop/graphql/config
```

example set:
```bash
curl \
  -X POST \
  -H "Content-Type: application/json" \
  --data '{"query": "mutation M { updateApp(authRedirectUri: \"<REDIRECT-URI>\", clientId: <ID>, clientSecret: \"<SECRET>\", name: \"<APP-NAME>\", nonce: \"<NONCE>\", scope: \"<APP-SCOPE>\") { name } }" }' \
http://localhost:4000/shop/graphql/config
```

### AuthTokens

example fetch:
```bash
curl \
  -X POST \
  -H "Content-Type: application/json" \
  --data '{"query": "{ allAuthTokens { appName, shopName, token, timestamp, code } }"}' \
http://localhost:4000/shop/graphql/config
```

example set:
```bash
curl \
  -X POST \
  -H "Content-Type: application/json" \
  --data '{"query": "mutation M { updateAuthToken(token: \"<TOKEN>\", timestamp: <TIMESTAMP>, shopName: \"<SHOPIFY-STORE-DOMAIN>\", code: \"<RESPONSE-CODE>\", appName: \"<APP-NAME>\") { appName } }" }' \
http://localhost:4000/shop/graphql/config
```

## Webhooks

Setting up webhook handling requires adding a handler to your configuration.

```elixir
config :shopify_api, webhook_filter: {MyApp.WebhookFilter, :process, []}
config :shopify_api, ShopifyAPI.Webhook, uri: "https://testapp.ngrok.io/shop/webhook"
```

A handler will need to be created

```elixir
defmodule MyApp.WebhookFilter do
  def process(%{action: "orders/create", object: %{}} = event) do
    IO.inspect(event, label: event)
    # ....
  end
end
```

And finally webhooks will have to be registered with Shopify. After installing a shop you will need to fire a webhook creation.

```elixir
token = ShopifyAPI.AuthTokenServer.get("shop domain", "app name")

topic = "orders/create"
server_address = ShopifyAPI.REST.Webhook.webhook_uri(token)
webhook = %{topic: topic, address: server_address}

ShopifyAPI.REST.Webhook.create(token, %{webhook: webhook})
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/shopify_api](https://hexdocs.pm/shopify_api).

