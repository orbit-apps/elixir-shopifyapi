use Mix.Config

# Print only warnings and errors during test
config :logger, level: :warn
config :bypass, adapter: Plug.Adapters.Cowboy2
