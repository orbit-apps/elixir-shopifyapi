# ShopifyAPI and Plug.ShopifyAPI

- [ShopifyAPI and Plug.ShopifyAPI](#ShopifyAPI-and-PlugShopifyAPI)
  - [Installation](#Installation)
  - [Installing this app in a Shop](#Installing-this-app-in-a-Shop)
  - [Configuration](#Configuration)
    - [API Version](#API-Version)
    - [CacheSupervisor](#cachesupervisor)
    - [Background Runner](#Background-Runner)
    - [Shops](#Shops)
    - [Apps](#Apps)
    - [AuthTokens](#AuthTokens)
  - [Webhooks](#Webhooks)
  - [GraphQL](#GraphQL)
  - [Telemetry](#Telemetry)

## Installation

The package can be installed by adding `shopify_api` to your list of dependencies in `mix.exs`.

```elixir
def deps do
  [
    {:shopify_api, github: "pixelunion/elixir-shopifyapi", tag: "v0.9.1"}
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
plug(ShopifyAPI.Plugs.Webhook, mount: "/shop/webhook")
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

There is a boilerplate repo for quickly getting up and running at [ShopifyApp](https://github.com/pixelunion/elixir-shopify-app)

1. Start something like ngrok
2. Configure your app to allow your ngrok url as one of the redirect_urls
3. Point your browser to `http://localhost:4000/shop/install?shop=your-shop.myshopify.com&app=yourapp` and it should prompt you to login and authorize it.


## Configuration

There is a GraphQL interface to get and update configuration, this is the recommended way of pushing configuration in to your server.

### API Version

Shopify introduced API versioning here: https://help.shopify.com/en/api/versioning

Configure the version to use in your config.exs, it will default to a stable version as ref'd in the [request module](lib/shopify_api/rest/request.ex).

```elixir
config :shopify_api, ShopifyAPI.REST, api_version: "2019-04"
```

### Cache Supervisor

The ShopifyAPI has three cache servers, App, Shop, and Auth Token. These speed up access to data structures used for interacting with Shopify. A supervisor, ShopifyAPI.CacheSupervisor, is there to help manage start up and maintain all three. Add the CacheSupervisor to your application start up and define [some hooks for preloading data](#Installation).

NOTE: Make sure you start the services or supervisor after services that are using in preloading the data. (ie Ecto)

Add the following to your application:

```elixir
def start(_type, _args) do
  # Define workers and child supervisors to be supervised
  children = [
    MyApp.Repo,
    ShopifyAPI.CacheSupervisor
  ]

  Supervisor.start_link(children, strategy: :one_for_one)
end
```

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

## GraphQL

`GraphQL` implementation handles GraphQL Queries against Shopify API using HTTPoison library as client, this initial implementation consists of hitting Shopify GraphQL and returning the response in a tuple `{:ok, %Response{}} | {:error, %Response{}}` containing the response and metadata(actualQueryCost, throttleStatus).

Configure the version to use in your config.exs, it will default to a stable version as ref'd in the [graphql module](lib/shopify_api/graphql.ex).


```elixir
config :shopify_api, ShopifyAPI.GraphQL, graphql_version: "2019-07"
```

### GraphQL Response

Because `GraphQL responses` can be a little complex we are parsing/wraping responses `%HTTPoison.response` to `%GraphQL.Response`.

Successful response:

```elixir
{:ok, %ShopifyAPI.GraphQL.Response{response: %{}, metadata: %{}, status_code: code}}
```

Failed response:

```elixir
{:error, %HTTPoison.Response{}}
```

## Telemetry

The `shopify_api` library will emit events using the [`:telemetry`](https://github.com/beam-telemetry/telemetry) library. Consumers of `shopify_api` can then use these events for customized metrics aggregation and more.
The following telemetry events are generated:
- `[:shopify_api, :rest_request, :success]`
- `[:shopify_api, :rest_request, :failure]`
- `[:shopify_api, :throttling, :over_limit]`
- `[:shopify_api, :throttling, :within_limit]`
- `[:shopify_api, :graphql_request, :success]`
- `[:shopify_api, :graphql_request, :failure]`

As an example, you could use an external module to instrument API requests made by `shopify_api`:

```elixir
defmodule Instrumenter do
  def setup do
    events = [
      [:shopify_api, :rest_request, :success],
      [:shopify_api, :rest_request, :failure]
    ]

    :telemetry.attach_many("my-instrumenter", events, &handle_event/4, nil)
  end

  def handle_event([:shopify_api, :rest_request, :success], measurements, metadata, _config) do
    # Ship success events
  end
end```
