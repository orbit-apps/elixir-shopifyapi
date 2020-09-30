defmodule ShopifyAPI.Application do
  use Application

  alias ShopifyAPI.RateLimiting

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    RateLimiting.RESTTracker.init()
    RateLimiting.GraphQLTracker.init()

    # Define workers and child supervisors to be supervised
    children = []

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: :shopify_api_supervisor]
    Supervisor.start_link(children, opts)
  end
end
