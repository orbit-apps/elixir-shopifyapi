defmodule ShopifyAPI.Application do
  use Application

  alias ShopifyAPI.AvailabilityTracker

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    AvailabilityTracker.init()

    # Define workers and child supervisors to be supervised
    children = [
      ShopifyAPI.ShopServer,
      ShopifyAPI.AppServer,
      ShopifyAPI.AuthTokenServer
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ShopifyAPI.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
