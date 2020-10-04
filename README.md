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
    {:shopify_api, github: "pixelunion/elixir-shopifyapi", tag: "v0.11.0"}
  ]
end
```

### Configuring Routes
You'll need to set up some routes in your Phoenix app routes to handle installation and authorization callbacks from Shopify. 

These will then need to be configured in the App setup page in Shopify. 

#### Built-in ShopifyAPI Routes
The ShopifyAPI library provides some convenience routes to you if you don't have a need to do any custom handling of authorization requests from Shopify.
Simply set a forwarding route in your Phoenix routes like this:

```elixir
scope "/shop" do
  forward("/", ShopifyAPI.Router)
end

```

Once that's done, you can set up your `App URL` in Shopify's App Configuration interface so it's using:
`[MY_APP_URL]/shop/start/[MY_APP_NAME]`

(where MY_APP_URL is the full url to your app and MY_APP_NAME is the `name` of your app as defined in the ShopifyAPI `App` entity -- the value stored in the local database, not the name of the app in Shopify.)

And you can set your `Allowed redirection URL(s)` in Shopify's App Configuration interface to:
```
[MY_APP_URL]/shop/install/[MY_APP_NAME]
[MY_APP_URL]/shop/run/[MY_APP_NAME]
```


for example, if I had an app I named `my_super_app` and my app were hosted at "https://shopify_apps.mydomain.com" and I set up my Phoenix routes as described above, then I'd configure Shopify's admin interface for my App so it used:
`https://shopify_apps.mydomain.com/shop/start/my_super_app`
for the `App URL` setting
and contained
```
 https://shopify_apps.mydomain.com/shop/install/my_super_app
 https://shopify_apps.mydomain.com/shop/run/my_super_app
 ```
 in the `Allowed redirection URL(s)` text area

### Handling Incoming Requests From Shopify
When using built-in routes, you'll need to configure the ShopifyAPI.Authorizer callbacks to handle incoming requests and forward them to your application controller logic.
 
In order to get things working, we need to ensure that Shopify can reach our server and that when it does reach our server that our app is handling things like we want it to. 
 
To do that, we configure the `ShopifyAPI.Authorizer` callbacks so that after ShopifyAPI handles a successful installation or authorization request that our app logic takes over.
 
 To set things up, we'll need something like the following set up in our Application configuration files.
 
 ```elixir
  config :shopify_api, ShopifyAPI.Authorizer,
         uri: Application.fetch_env!(:shopify_app, :shopify_conf)[:apps_base_url],
         post_install: {MyAppWeb.AppController, :post_install},
         run_app: {MyAppWeb.AppController, :run_app}

```

and the analog logic set up and ready to handle these requests. 

For example:
 
 ```elixir
# config.exs
import Config
...
  # this is the full url to your app as would be required by Shopify to reach your server. 
  # additionally, the path to the mounted ShopifyAPI routes is appended
config :shopify_app, :shopify_conf,
       apps_base_url: "#{System.get_env("APP_HOST_URI")}"

...
```

```elixir

defmodule MyAppWeb.AppController do
  def post_install(conn) do
    ...
  end

  def run_app(conn) do
    ...
  end
end
```

#### Custom Routes
If you'd prefer not to use the built-in routes provided by ShopifyAPI, you can set up your own & hook ShopifyAPI's authorization logic into your controller.

##### Custom Authorization Route
The first route will be for handling incoming app requests to your server. 

for example:
```elixir
    get "/app/start/:app_name", MyApp.AppController, :authorize_request
```

This will be the URI you've configured as the `App URL` in the `URLs` section of your App setup in Shopify.

If you don't need to add any custom handling logic to the incoming request, you can use the 
built-in ShopifyAPI library initialization logic by configuring `App URL` in the `URLs` section of your App setup in Shopify to go to `[YOUR APP URL]/[]

##### Custom Installation Route
 This will be where users are redirected to after they've installed your app in their shop in Shopify. Because the app installation process for an embedded app requires breaking out of the app iframe in shopify ([as seen here](https://shopify.dev/tools/app-bridge/getting-started#authenticate-with-oauth)), you may want to have a separate, dedicated app installation route set up, and special logic for handling the completion of the app installation. This will be configured as one of your `Allowed Redirection URLs` in the `URLs` Section of your App setup in Shopify.

for example:
```elixir
    get "app/install/:app_name", MyApp.AppController, :finish_app_install

```

##### Custom App Run Route
This is the route to your application logic. This will be configured as one of your `Allowed Redirection URLs` in the `URLs` Section of your App setup in Shopify.

for example:
```elixir
    get "/app/run/:app_name", MyApp.AppController, :run_app
```


### Configuring Webhooks
If you want to be able to handle webhooks you need to add this to your endpoint before the parsers section
```elixir
plug(ShopifyAPI.Plugs.Webhook, mount: "/shop/webhook")
```

### Configuring Library Callback Hooks
The following callback hooks are provided so that you can hook your own logic into events as they occur.

#### Data Persistence Callbacks
If you want persisted Apps, Shops, and Tokens, use the following hooks.

##### `AuthTokenServer` callbacks
`AuthTokenServer` provides you two callback mechanisms to hook into: `initializer` to handle hydrating the datastore from your database on app start and `persistance` to allow you to store AuthToken data in your database.

```elixir
config :shopify_api, ShopifyAPI.AuthTokenServer,
  initializer: {MyApp.AuthToken, :init, []},
  persistance: {MyApp.AuthToken, :save, []}
```
* `initializer` Use this callback to provide your app a way to hydrate the AuthTokenServer data store on application startup.
* `persistance` Use this callback to provide your app a way to persist AuthToken data.

##### `AppServer` callbacks
`AppServer` provides you two callback mechanisms to hook into: `initializer` to handle hydrating the AuthTokenServer datastore from your database on app start and `persistance` to allow you to store App data in your database.

```elixir
config :shopify_api, ShopifyAPI.AppServer,
  initializer: {MyApp.ShopifyApp, :init, []},
  persistance: {MyApp.ShopifyApp, :save, []}
```
* `initializer` Use this callback to provide your app a way to hydrate the AppServer data store on application startup.
* `persistance` Use this callback to provide your app a way to persist AppServer data.

##### `ShopServer` callbacks
`ShopServer` provides you two callback mechanisms to hook into: `initializer` to handle hydrating the ShopServer datastore from your database on app start and `persistance` to allow you to store Shop data in your database.

```elixir
config :shopify_api, ShopifyAPI.ShopServer,
  initializer: {MyApp.Shop, :init, []},
  persistance: {MyApp.Shop, :save, []}
```
* `initializer` Use this callback to provide your app a way to hydrate the ShopServer data store on application startup.
* `persistance` Use this callback to provide your app a way to persist ShopServer data.

##### `Shop` callbacks
```elixir
  config :shopify_api, ShopifyAPI.Shop,
         post_install: {MyApp.Shop, :post_app_install_callback, []}
```
* `post_install` Use this callback to provide your app a way to perform custom actions to take place after the application has been installed in a shop. 

#### OAuth Callbacks

##### `App` callbacks
These callbacks are used in the Shopify OAuth flow. They give you the ability to define the URI
that Shopify will redirect to after installing the app, and the one Shopify will go to after Shopify 
has authorized the request to your app. These should be the routes you've set up in your Phoenix app.

These URLs would need to be configured in the Shopify App setup interface under the
`Allowed redirection URL(s)` section in order to work.

```elixir
  config :shopify_api, ShopifyAPI.App,
         install_uri: {MyApp.App, :install_uri, []},
         run_url: {MyApp.App, :run_url, []}
```

* `install_uri` Use this callback to give your app a way to show a custom page or to perform some custom logic once the app has been installed. This will only be performed once -- upon completion of installation of the app in the store.
* `run_url` Use this callback as a hook to start your application logic once the OAuth authentication process has completed. This will be performed every time the app is started and the request has been authenticated by Shopify.

When using this, your callback functions should handle a `app:` named argument when generating the uri. 

For example:

```elixir
defmodule MyApp.App do
    def install_uri(app: %ShopifyAPI.App{} = app) do
          "https://testapp.ngrok.io/shop/install/#{app.name}"
    end

    def run_url(app: %ShopifyAPI.App{} = app) do
          "https://testapp.ngrok.io/shop/run/#{app.name}"
    end
end
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
