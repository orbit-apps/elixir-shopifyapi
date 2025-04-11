# ShopifyAPI and Plug.ShopifyAPI

- [ShopifyAPI and Plug.ShopifyAPI](#ShopifyAPI-and-PlugShopifyAPI)
  - [Installation](#Installation)
  - [Installing this app in a Shop](#Installing-this-app-in-a-Shop)
  - [Configuration](#Configuration)
    - [API Version](#API-Version)
    - [Supervisor](#supervisor)
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
    {:shopify_api, github: "pixelunion/elixir-shopifyapi", tag: "v0.16.4"}
  ]
end
```

Add it to your phoenix routes.

```elixir
scope "/shop" do
  forward("/", ShopifyAPI.Router)
end
```

To handle incoming webhooks from Shopify, add the `ShopifyAPI.Plugs.Webhook` to your `Endpoint` module (before the JSON parser configuration):

```elixir
plug ShopifyAPI.Plugs.Webhook,
  app_name: "my-app-name",
  prefix: "/shopify/webhook",
  callback: {WebhookHandler, :handle_webhook, []}
```

If you want persisted Apps, Shops, and Tokens add configuration to your functions.
```elixir
config :shopify_api, ShopifyAPI.AuthTokenServer,
  initializer: {MyApp.AuthToken, :init, []},
  persistence: {MyApp.AuthToken, :save, []}
config :shopify_api, ShopifyAPI.AppServer,
  initializer: {MyApp.ShopifyApp, :init, []},
  persistence: {MyApp.ShopifyApp, :save, []}
config :shopify_api, ShopifyAPI.ShopServer,
  initializer: {MyApp.Shop, :init, []},
  persistence: {MyApp.Shop, :save, []}
```

## Installing this app in a Shop

There is a boilerplate repo for quickly getting up and running at [ShopifyApp](https://github.com/pixelunion/elixir-shopify-app)

1. Start something like ngrok
2. Configure your app to allow your ngrok url as one of the redirect_urls
3. Point your browser to `http://localhost:4000/shop/install?shop=your-shop.myshopify.com&app=yourapp` and it should prompt you to login and authorize it.


## Configuration

### API Version

Shopify introduced API versioning here: https://help.shopify.com/en/api/versioning

Configure the version to use in your config.exs, it will default to a stable version as ref'd in the [request module](lib/shopify_api/rest/request.ex).

```elixir
config :shopify_api, ShopifyAPI.REST, api_version: "2019-04"
```

### Supervisor

The ShopifyAPI has three servers for caching commonly-used structs - `AppServer`, `ShopServer`, and `AuthTokenServer`.
These act as a write-through caching layer for their corresponding data structure.

A supervisor `ShopifyAPI.Supervisor` is provided to start up and supervise all three servers.
Add it to your application's supervision tree, and define [hooks for preloading data](#Installation).

NOTE: Make sure you place the supervisor after any dependencies used in preloading the data. (ie Ecto)

Add the following to your application:

```elixir
def start(_type, _args) do
  children = [
    MyApp.Repo,
    ShopifyAPI.Supervisor
  ]

  Supervisor.start_link(children, strategy: :one_for_one)
end
```

## Webhooks

Add a custom body reader and HMAC validation to your parser config `body_reader: {ShopifyAPI.WebhookHMACValidator, :read_body, []}` Your parser should now look like:
```elixir
plug Plug.Parsers,
  parsers: [:urlencoded, :multipart, :json],
  pass: ["*/*"],
  body_reader: {ShopifyAPI.WebhookHMACValidator, :read_body, []},
  json_decoder: Phoenix.json_library()
```

Add a route:
```elixir
pipeline :shopify_webhook do
  plug ShopifyAPI.Plugs.WebhookEnsureValidation
  plug ShopifyAPI.Plugs.WebhookScopeSetup
end

scope "/shopify/webhook", MyAppWeb do
  pipe_through :shopify_webhook
  # The app_name path param is optional if the `config :shopify_api, :app_name, "my_app"` is set
  post "/:app_name", ShopifyWebhooksController, :webhook
end
```

Add a controller:
```elixir
defmodule SectionsAppWeb.ShopifyWebhooksController do
  use SectionsAppWeb, :controller
  require Logger

  def webhook(
        %{assigns: %{webhook_scope: %{topic: "app_subscriptions/update"} = webhook_scope}} = conn,
        params
      ) do
    Logger.warning("Doing work on app subscription update with params #{inspect(params)}",
      myshopify_domain: webhook_scope.myshopify_domain
    )

    json(conn, %{success: true})
  end

  def webhook(%{assigns: %{webhook_scope: webhook_scope}} = conn, _params) do
    Logger.warning("Unhandled webhook: #{inspect(webhook_scope.topic)}")
    json(conn, %{success: true})
  end
end
```

The old `ShopifyAPI.Plugs.Webhook` method has been deprecated.

Now webhooks sent to `YOUR_URL/shopify/webhook` will be interpreted as webhooks for the `my-app-name` app.
If you append an app name to the URL in the Shopify configuration, that app will be used instead (e.g. `/shopify/webhook/private-app-name`).

If you'd like to install webhooks using ShopifyAPI, we need to do a small bit more work:

```elixir
# Add this to your configuration so that ShopifyAPI knows the webhook prefix.
config :shopify_api, ShopifyAPI.Webhook, uri: "https://your-app-url/shop/webhook"
```

Now once a shop is installed, you can create webhook subscriptions.
This will automatically append your app's name to the generated webhook URL:

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
- `[:shopify_api, :bulk_operation, :success]`
- `[:shopify_api, :bulk_operation, :failure]`

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
