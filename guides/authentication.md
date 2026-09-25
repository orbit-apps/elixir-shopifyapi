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

Any time a module needs a token to call the Shopify API, read it with
`ShopifyAPI.AuthToken.fetch/2`:

```elixir
case ShopifyAPI.AuthToken.fetch(shop.domain, MyApp.app_name()) do
  {:ok, auth_token} -> do_the_work(auth_token)
  {:error, :not_found} -> cancel("shop has no token")
  {:error, :needs_reacquisition} -> cancel_and_flag(shop)
end
```

Any other failure raises. `ShopifyAPI.TokenRefreshError` means Shopify failed
the refresh, or the exchange of a permanent token under `:exchange_permanent`
(see below). `ShopifyAPI.TokenPersistenceError` means the new pair could not be
stored. Both are transient: a background job should let them propagate and be
retried, and Plug renders them as a `503`. Neither plug above treats either as
a missing token.

`ShopifyAPI.TokenMigrationError` is the exception to that. Only
`:exchange_permanent` raises it, and only once Shopify has already revoked the
permanent token, so retrying cannot help — the shop has no working credential
until it reinstalls. Page on it rather than retrying it.

`ShopifyAPI.AuthTokenServer.get/2` returns whatever the cache holds, expired or
not. `fetch/2` checks the expiry and refreshes when needed.

## Expiring tokens

Shopify issues offline tokens in two shapes. A _permanent_ token never expires.
An _expiring_ token lives for an hour and comes with a refresh token; refreshing
replaces both the access token and the refresh token at once.

Shopify has required expiring tokens of new public apps since April 2026 and
stops accepting permanent ones on 1 January 2027.

### Opting in

```elixir
config :shopify_api, offline_tokens: :expiring
```

`:offline_tokens` takes one of three values:

| Value                  | New token requests | A permanent token read by `fetch/2`  |
| ---------------------- | ------------------ | ------------------------------------ |
| `:permanent` (default) | permanent          | returned as is                       |
| `:expiring`            | expiring           | returned as is                       |
| `:exchange_permanent`  | expiring           | exchanged for an expiring pair first |

New token requests are both the OAuth code grant and token exchange. A token
that already carries a refresh token is refreshed whatever the setting, so
turning it back to `:permanent` does not strand shops that already have one.

The older `expiring: true` and `expiring: false` still work, as `:expiring` and
`:permanent`. `:offline_tokens` wins when both are set.

### Migrating existing shops

`:expiring` only affects shops that install or reinstall afterwards. Shops that
installed earlier keep their permanent token until you move them, either as
they are used or in a sweep.
`ShopifyAPI.AuthRequest.migrate_offline_access_token/2` performs the one-time
exchange in both cases, and always requests an expiring pair whatever
`:offline_tokens` is set to.

With `offline_tokens: :exchange_permanent`, `ShopifyAPI.AuthToken.fetch/2`
exchanges a shop's permanent token the first time it reads it, and returns the
new pair. Concurrent callers wait on a single exchange. A spent token comes back
as `{:error, :needs_reacquisition}`, and an exchange that fails before Shopify
revokes the permanent token raises `ShopifyAPI.TokenRefreshError`, so the next
fetch tries again.

> #### Exchange after the cutover is observed, not documented {: .warning}
>
> Shopify does not say whether a permanent token can still be exchanged after
> 1 January 2027. The one data point is a public app created after April 2026:
> the Admin API already refuses its permanent tokens with a `403`, yet one could
> still be exchanged for an expiring pair. `:exchange_permanent` assumes existing
> apps will behave the same way after the cutover. If they do not, fetching a
> shop still on a permanent token raises `ShopifyAPI.TokenRefreshError` every
> time, so migrate what you can before then.

> #### Only one exchanger per token {: .warning}
>
> The exchange is de-duplicated within this node only. If another application
> holds the same permanent tokens and exchanges them too, whichever goes second
> gets a spent token. This library then returns
> `{:error, :needs_reacquisition}`, because it has no way to load the other
> application's pair from storage. Enable `:exchange_permanent` only where
> nothing else exchanges the same tokens.

Shops that make no API calls are never fetched, so they are never exchanged
that way. Sweep the permanent tokens still in your storage to reach them before
1 January 2027:

```elixir
ShopifyAPI.AuthTokenServer.all()
|> Map.values()
|> Enum.filter(&is_nil(&1.refresh_token))
|> Enum.each(fn token ->
  {:ok, app} = ShopifyAPI.AppServer.get(token.app_name)

  case ShopifyAPI.AuthRequest.migrate_offline_access_token(app, token) do
    {:ok, _migrated} -> :ok
    {:error, :already_expiring} -> :ok
    {:error, :invalid_subject_token} -> flag_for_reacquisition(token)
    {:error, {:failed_migrating_offline_token, failure}} -> retry_later(token, failure)
  end
end)
```

The exchange has no safety net. Shopify revokes the permanent token in the same
step that issues the expiring pair, and the spent token cannot be re-presented,
so unlike a refresh there is no replay. Everything hinges on the moment it
succeeds:

- A refused or failed exchange leaves the permanent token intact — the shop is
  safe to skip and the batch safe to re-run. These return `{:error, _}`.
- A successful exchange whose pair never reaches storage leaves the shop with no
  working credential, recoverable only by a merchant reinstall. This raises
  `ShopifyAPI.TokenMigrationError` — page on it.

So your persistence callback must raise on write failure rather than logging and
returning (see the next section), and the migration should run in small
committed batches so the window between exchange and commit stays short. Re-runs
are safe: a shop already moved is skipped by the `refresh_token` filter, and one
Shopify reports as already migrated comes back as
`{:error, :invalid_subject_token}`.

### Scheduled refreshing

`ShopifyAPI.AuthToken.fetch/2` refreshes tokens automatically, so shops with
active API callers stay current. Your application is responsible for refreshing
inactive shops — a refresh token that is never used lapses after ninety days.

Shopify replays a refresh token for **thirty days** after its first use — if a
refreshed pair reaches the cache but not your database, or you restore an older
backup, the stale refresh token still works within that window. Schedule a sweep
on a shorter cadence to keep every shop inside it.
`ShopifyAPI.Refresh.shops_needing_refresh/1` selects the tokens due.

### Persistence changes

Your persistence callback needs three additional columns: `token_expires_at`,
`refresh_token` and `refresh_token_expires_at`. All three must appear in the
Ecto `:replace` list — omitting any of them silently preserves stale values, and
the token stops working when the old refresh token expires.

The callback must raise on write failure rather than logging and returning. See
`ShopifyAPI.AuthTokenServer` for why and a worked Ecto example.

### Testing

`ShopifyAPI.Test` builds tokens in each expiry state: live, expired but
refreshable, and dead.

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
