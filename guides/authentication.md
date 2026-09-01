# Authentication

How a shop gets installed, where its credentials end up, and what authenticates
each request afterwards.

## The pieces

Four structs, each cached by a matching server, all started by
`ShopifyAPI.Supervisor`:

| Struct                 | Cache                        | Keyed by            | Holds                             |
| ---------------------- | ---------------------------- | ------------------- | --------------------------------- |
| `ShopifyAPI.App`       | `ShopifyAPI.AppServer`       | app name            | your client id, secret and scopes |
| `ShopifyAPI.Shop`      | `ShopifyAPI.ShopServer`      | myshopify domain    | little more than the domain       |
| `ShopifyAPI.AuthToken` | `ShopifyAPI.AuthTokenServer` | `{shop, app}`       | the offline token API calls use   |
| `ShopifyAPI.UserToken` | `ShopifyAPI.UserTokenServer` | `{shop, app, user}` | a staff member's online token     |

The caches are ETS-backed and empty at boot. They repopulate from an
`initializer` callback and write out through a `persistence` callback — the
contract for both is documented on `ShopifyAPI.AuthTokenServer`. Apps come from
your configuration or database; tokens come from installing.

## Two ways to get a token

**The OAuth redirect**, implemented by `ShopifyAPI.Router`. The merchant is
bounced to Shopify, approves the scopes, and is redirected back with a `code`
that gets exchanged for a token. This is what an app mounting the router uses.

**Token exchange**, implemented by `ShopifyAPI.JWTSessionToken`. An embedded app
already receives a signed session token on every request from App Bridge, and
can trade it for an access token with no redirects at all.

They are not exclusive. An app can mount the router for first-time installs and
still use `ShopifyAPI.JWTSessionToken.get_offline_token/2` on request paths —
the latter falls back to exchange only when the cache has nothing, so it is
cheap to call.

## Setting up

Start the supervisor after anything its initializers need:

```elixir
def start(_type, _args) do
  children = [MyApp.Repo, ShopifyAPI.Supervisor]
  Supervisor.start_link(children, strategy: :one_for_one)
end
```

Tell the caches how to load and save. Apps are usually seeded from config and
never written back; tokens must be persisted or every restart logs your shops
out:

```elixir
config :shopify_api, ShopifyAPI.AppServer,
  initializer: {MyApp.ShopifyApp, :init, []}

config :shopify_api, ShopifyAPI.AuthTokenServer,
  initializer: {MyApp.AuthToken, :init, []},
  persistence: {MyApp.AuthToken, :save, []}
```

Forward a scope to the router, and register a hook to run when a shop finishes
authenticating:

```elixir
scope "/shop" do
  forward("/", ShopifyAPI.Router)
end
```

```elixir
config :shopify_api, ShopifyAPI.Shop, post_login: {MyApp.Shop, :post_login, []}
```

## Installing a shop

```
GET /shop/install?shop=acme.myshopify.com&app=my-app
      │
      │  ShopifyAPI.Router looks the app up in AppServer
      ▼
302 → https://acme.myshopify.com/admin/oauth/authorize?...
      │
      │  merchant approves the scopes
      ▼
GET /shop/authorized/my-app?code=…&state=…&hmac=…&timestamp=…
      │
      ├─ check `state` against the app's nonce
      ├─ verify the query string HMAC with the client secret
      ├─ ShopifyAPI.App.fetch_token/3 → POST /admin/oauth/access_token
      ├─ ShopServer.set/2  +  AuthTokenServer.set/2   (persistence fires here)
      └─ ShopifyAPI.Shop.post_login/1
      ▼
302 → https://acme.myshopify.com/admin/apps/<client_id>
```

Whether the token is a `ShopifyAPI.AuthToken` or a `ShopifyAPI.UserToken`
depends on the app's access mode; each goes to its own cache. Any failure along
the way is a bare `404`.

## Multiple apps in one deployment

Nothing here assumes you have only one Shopify app. `ShopifyAPI.AppServer` is
keyed by app name, so your initializer can return several — a main app and its
companions, each with its own client id, secret and scopes — and the rest of the
library follows: tokens are keyed by `{shop, app}`, so one shop can install all
of them; the router's `:app` path segment picks which app an install runs as;
and `ShopifyAPI.Plugs.Webhook` needs the app name in its URL because Shopify
does not include it in the payload.

Give each app an `auth_redirect_uri` ending in its own name and one mounted
router serves them all:

```elixir
def init do
  [
    %ShopifyAPI.App{
      name: "my-app",
      client_id: ...,
      client_secret: ...,
      auth_redirect_uri: "https://example.com/shop/authorized/my-app"
    },
    %ShopifyAPI.App{
      name: "my-companion-app",
      client_id: ...,
      client_secret: ...,
      auth_redirect_uri: "https://example.com/shop/authorized/my-companion-app"
    }
  ]
end
```

A persistence callback can then route each app's tokens wherever it likes by
matching on `app_name`, since it receives the whole token struct.

## Authenticating requests afterwards

`ShopifyAPI.Plugs.AdminAuthenticator` guards the first load of an embedded app:
it verifies the request, resolves the shop, app and token, and assigns them to
the conn. If no token is cached it redirects into the install flow above, which
is what makes a revoked or never-installed shop recover on its own.

`ShopifyAPI.Plugs.AuthShopSessionToken` guards the requests that follow, where
the frontend sends a session token as `Authorization: Bearer`. It assigns the
same things.

Either way your controllers read `conn.assigns.auth_token` and hand it to
`ShopifyAPI.REST` or `ShopifyAPI.GraphQL`.

## Uninstalling

Shopify revokes the token and sends an `app/uninstalled` webhook. Nothing in
this library acts on it, so clear both your own storage and the caches —
`delete/2` and friends do not call the persistence callback, and anything left
in your database is loaded straight back in on the next restart:

```elixir
def handle_webhook(_app, shop, "app/uninstalled", _payload) do
  MyApp.Shops.delete(shop.domain)

  ShopifyAPI.ShopServer.delete(shop.domain)
  ShopifyAPI.AuthTokenServer.delete(shop.domain, MyApp.app_name())
  ShopifyAPI.UserTokenServer.delete_for_shop(shop.domain)
end
```

Webhooks are handled by `ShopifyAPI.Plugs.Webhook` mounted in your endpoint, not
by `ShopifyAPI.Router` — it exposes no webhook route.
