## Unreleased

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
