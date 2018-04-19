# ShopifyApi and Plug.ShopifyApi

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
  forward("/", ShopifyApi.Router)
end
```

## Installing this app in a Shop

1. Start something like ngrok
2. Configure your app to allow your ngrok url as one of the redirect_urls
3. Point your browser to `http://localhost:4000/shop/install?shop=your-shop.shopify.com&app=yourapp` and it should prompt you to login and authorize it.

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/shopify_api](https://hexdocs.pm/shopify_api).

