use Mix.Config

config :exq, start_on_application: false

# Print only warnings and errors during test
config :logger, level: :warn
config :bypass, adapter: Plug.Adapters.Cowboy2

config :shopify_api, :customer_api_secret_keys, ["new_secret", "old_secret"]
