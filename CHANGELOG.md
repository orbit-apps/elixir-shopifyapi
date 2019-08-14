## Unreleased

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
