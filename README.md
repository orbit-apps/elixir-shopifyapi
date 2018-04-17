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
  forward "/", Plug.ShopifyApi
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/shopify_api](https://hexdocs.pm/shopify_api).

