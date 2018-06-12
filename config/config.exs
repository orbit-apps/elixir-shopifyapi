# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure your application as:
#
#     config :shopify_api, key: :value
#
# and access this configuration in your application as:
#
#     Application.get_env(:shopify_api, :key)
#
# You can also configure a 3rd-party app:
#
#     config :logger, level: :info
#

# Provider out server with a min of an empty Map
config :shopify_api, ShopifyAPI.Shop, %{}
config :shopify_api, ShopifyAPI.App, %{}

config :exq,
  host: "127.0.0.1",
  port: 6379,
  namespace: "shopify",
  concurrency: :infinite,
  queues: ["default"],
  poll_timeout: 50,
  shutdown_timeout: 5000,
  middleware: [
    Exq.Middleware.Stats,
    Exq.Middleware.Job,
    Exq.Middleware.Manager,
    Exq.Middleware.Logger,
    Exq.Middleware.AtomizeJobArguments
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
