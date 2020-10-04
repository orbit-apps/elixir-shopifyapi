use Mix.Config

# Print only warnings and errors during test
config :logger, level: :warn
config :bypass, adapter: Plug.Adapters.Cowboy2

config :shopify_api,
  customer_api_secret_keys: ["new_secret", "old_secret"],
  transport: "http://",
  bypass_host: "localhost:62323",
  bypass_port: 62323
