defmodule ShopifyAPI.Application do
  use Application

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec

    # Define workers and child supervisors to be supervised
    children = [
      supervisor(ShopifyAPI.ShopServer, []),
      supervisor(ShopifyAPI.AppServer, []),
      supervisor(ShopifyAPI.AuthTokenServer, []),
      supervisor(ShopifyAPI.EventPipe.Supervisor, [%{}])
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ShopifyAPI.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
