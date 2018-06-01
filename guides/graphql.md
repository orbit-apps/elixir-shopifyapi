# Configure GraphQL

## Getting Started

There is a GraphQL interface to get and update configuration, this is the recommended way of pushing configuration in to your server.

Optional, add GraphiQL to your Phoenix config:

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

## Examples

example fetch:

```sh
curl \
  -X POST \
  -H "Content-Type: application/json" \
  --data '{"query": "{ allShops { domain } }"}' \
http://localhost:4000/shop/graphql/config
```

example set:

```sh
curl \
  -X POST \
  -H "Content-Type: application/json" \
  --data '{"query": "mutation M { updateShop(domain: \"<STORE-DOMAIN>\",) { domain } }" }' \
http://localhost:4000/shop/graphql/config
```

### Apps

example fetch:

```sh
curl \
  -X POST \
  -H "Content-Type: application/json" \
  --data '{"query": "{ allApps { authRedirectUri, clientId, clientSecret, name, nonce, scope } }"}' \
http://localhost:4000/shop/graphql/config
```

example set:

```sh
curl \
  -X POST \
  -H "Content-Type: application/json" \
  --data '{"query": "mutation M { updateApp(authRedirectUri: \"<REDIRECT-URI>\", clientId: <ID>, clientSecret: \"<SECRET>\", name: \"<APP-NAME>\", nonce: \"<NONCE>\", scope: \"<APP-SCOPE>\") { name } }" }' \
http://localhost:4000/shop/graphql/config
```

### AuthTokens

example fetch:

```sh
curl \
  -X POST \
  -H "Content-Type: application/json" \
  --data '{"query": "{ allAuthTokens { appName, shopName, token, timestamp, code } }"}' \
http://localhost:4000/shop/graphql/config
```

example set:

```sh
curl \
  -X POST \
  -H "Content-Type: application/json" \
  --data '{"query": "mutation M { updateAuthToken(token: \"<TOKEN>\", timestamp: <TIMESTAMP>, shopName: \"<SHOPIFY-STORE-DOMAIN>\", code: \"<RESPONSE-CODE>\", appName: \"<APP-NAME>\") { appName } }" }' \
http://localhost:4000/shop/graphql/config
```
