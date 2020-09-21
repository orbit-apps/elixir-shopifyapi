## Unreleased

## 0.9.3

- Fix: Bulk Telemetry event name is now correct.

## 0.9.2

- Add new ShopifyAPI.Bulk error types
- Add ShopifyAPI.Bulk :telemetry events

## 0.9.1

- Fix: Bulk.process_stream!/2 now correctly handles bulk operations returning 0 objects

## 0.9.0

- Add HTTP fetch streaming in Bulk.Query with stream_fetch/1
- BREAKING: Bulk.process_stream/2 is now Bulk.process_stream!/2 and no longer returns errors in a list.
  - Now streams HTTP body.

## 0.8.4

- Fix: `Bulk.Cancel.poll/5` uses the correct arguments while recursing.

## 0.8.3

- Added max poll count configuration option to GraphQL Bulk Query.
- Fix: `all/3` for smart_collection and custom_collection works.
- BREAKING: moved the bulk query functionality namespaces from `ShopifyAPI.GraphQL.BulkFetch` to `ShopifyAPI.Bulk`

## 0.8.2

- Add throttling for GraphQL.
- Add GraphQL bulk fetch query method.
- Switch default version of GraphQL API to 2019-10 (was 2019-07).

## 0.8.1

- Fix: Remove call to `String.to_existing_atom` from param serialization. This could previously result in an unexpected error from the caller.

## 0.8.0

- BREAKING: Switch default version of REST API to 2020-01 (was 2019-04).
- BREAKING: Add ability to specify pagination options for GET on collection resources, defaults to blocking until all results returned.
- BREAKING: Removed top-level wrappers of Shopify REST response values.
  - Return values that were `{:ok, %{"orders" => [%{}, ...]}}` are now `{:ok, [%{}, ...]}`
- BREAKING: Removed `Exq` dependency, EventPipe.EventQueue & EventPipe.ModuleNameWorker & surrounding modules.

## 0.7.2

- Fixes an incorrect arity bug in `GraphQL.Response.handle`

## 0.7.0

- Refactor caching servers startup, no longer started by ShopifyAPI.Application
  WARNING this is a breaking change, it will require the addition of the cache supervisor to the applications children.
- Fix nested tuple returns on things like Shopify timeouts.
  WARNING This is a breaking change, errors returned as `{:error, {:error, any()}}` will be `{:error, any()}` now.
- Increased minimum supported version of Elixir to "1.9"

## 0.6.0

- Add internal GraphQL interface to Shopify's GraphQL API

## 0.5.1

- Add Customer Authentication Plug [ch51782]
- Move to Jason as default json encoder, no longer has deps for Poison.

## 0.5.0

- `AuthTokenServer.get` spec has been changed. It will return `{:error, any()}` if it can't find an AuthToken.
- Configurable json serialization.

## 0.4.3

- Refactor `ShopifyAPI.REST.Request`, extract underlying `get`/`post`/`put`/`delete` to `ShopifyAPI.REST`.
- Correct examples for `ShopifyAPI.REST.Collect`.
- Refactor ThrottlingServer -> AvailabilityTracker
- Add :telemetry events

## 0.4.1

- Add support for serializing `%ShopifyAPI.EventPipe.Event{}` structs with Jason.

## 0.4.0

- Add BackgroundJobBehaviour to allow configure the job runner
- Add Credo and compile warnings to CI

## 0.3.1

- Fix for ApplicationCredit

## 0.3.0

- Support API versioning
- Coerce events from the queue into %Events{}
- Change Events in EventQueue to use string destinations and actions
- Changed Event.t() typespec to be strings for destination and action.

## 0.2.7

- Added new endpoint for customer search
- Added new endpoints for draft orders
- Added the ShopifyAPI namespace prefix to the GraphQL modules

## 0.2.6

- Fixed dialyzer, thank you @baradoy!
- Type for Event work
- Make exq optional (turning it off for test runs), if Exq isn't running work will be run inline.

## 0.2.5

- Add new Plug.AdminAuthenticator for easy Shop admin panel authentication
- Refactor Plug.Webhook

## 0.2.4

- Bump Exq ver and use Jason encoding for jobs
- Add REST.Asset and REST.Theme

## 0.2.3

- Added filter params to REST.Metafield.all/2&3

## 0.2.2

- REST.Metafield.all/1 fix

## 0.2.1

- Fix bug in server initialization params, make AuthTokenServers init match the other servers

## 0.2.0

- Initialization and persistance hooks added to ShopServer and AppServer (following the AuthTokenServer example)
- HTTPoison upgrade to 1.5.0
