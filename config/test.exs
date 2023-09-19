import Config

# Print only warnings and errors during test
config :logger, level: :warning
config :bypass, adapter: Plug.Adapters.Cowboy2

config :shopify_api,
  customer_api_secret_keys: ["new_secret", "old_secret"],
  transport: "http"
