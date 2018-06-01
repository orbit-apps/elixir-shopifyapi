# Installation

## Getting Started

Add `shopify_api` to your list of dependencies in `mix.exs` and add the application to the `extra_applications`:

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

```elixir
scope "/shop" do
  forward("/", ShopifyApi.Router)
end
```
