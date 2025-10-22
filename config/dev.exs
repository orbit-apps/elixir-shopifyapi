import Config

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

config :shopify_api, :app_name, "shopify_test_app"
