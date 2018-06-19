# ShopifyAPI and Plug.ShopifyAPI

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `shopify_api` to your list of dependencies in `mix.exs` and add the application to the `extra_applications`:

```elixir
def application do
  [
    mod: {...}
    extra_applications: [..., :shopify_api]
  ]
end

def deps do
  [
    {:shopify_api, "~> 0.1.0"}
  ]
end
```

Add it to your phoenix routes.

```
scope "/shop" do
  forward("/", ShopifyAPI.Router)
end
```

If you want to be able to handle webhooks you need to add this to your endpoint before the parsers section
```
plug(ShopifyAPI.Plugs.Webhook, mount: "/shop/webhooks")
```

Optional, add graphiql to your phoenix routes
```
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
3. Point your browser to `http://localhost:4000/shop/install?shop=your-shop.shopify.com&app=yourapp` and it should prompt you to login and authorize it.


## Configuration

There is a GraphQL interface to get and update configuration, this is the recommended way of pushing configuration in to your server.

### Shops

example fetch:
```
curl \
  -X POST \
  -H "Content-Type: application/json" \
  --data '{"query": "{ allShops { domain } }"}' \
http://localhost:4000/shop/graphql/config
```

example set:
```
curl \
  -X POST \
  -H "Content-Type: application/json" \
  --data '{"query": "mutation M { updateShop(domain: \"<STORE-DOMAIN>\",) { domain } }" }' \
http://localhost:4000/shop/graphql/config
```

### Apps

example fetch:
```
curl \
  -X POST \
  -H "Content-Type: application/json" \
  --data '{"query": "{ allApps { authRedirectUri, clientId, clientSecret, name, nonce, scope } }"}' \
http://localhost:4000/shop/graphql/config
```

example set:
```
curl \
  -X POST \
  -H "Content-Type: application/json" \
  --data '{"query": "mutation M { updateApp(authRedirectUri: \"<REDIRECT-URI>\", clientId: <ID>, clientSecret: \"<SECRET>\", name: \"<APP-NAME>\", nonce: \"<NONCE>\", scope: \"<APP-SCOPE>\") { name } }" }' \
http://localhost:4000/shop/graphql/config
```

### AuthTokens

example fetch:
```
curl \
  -X POST \
  -H "Content-Type: application/json" \
  --data '{"query": "{ allAuthTokens { appName, shopName, token, timestamp, code } }"}' \
http://localhost:4000/shop/graphql/config
```

example set:
```
curl \
  -X POST \
  -H "Content-Type: application/json" \
  --data '{"query": "mutation M { updateAuthToken(token: \"<TOKEN>\", timestamp: <TIMESTAMP>, shopName: \"<SHOPIFY-STORE-DOMAIN>\", code: \"<RESPONSE-CODE>\", appName: \"<APP-NAME>\") { appName } }" }' \
http://localhost:4000/shop/graphql/config
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/shopify_api](https://hexdocs.pm/shopify_api).

