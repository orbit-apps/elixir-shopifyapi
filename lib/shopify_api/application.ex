defmodule ShopifyApi.Application do
  use Application

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec

    # Define workers and child supervisors to be supervised
    children = [
      supervisor(ShopifyApi.ShopServer, []),
      supervisor(ShopifyApi.AppServer, []),
      supervisor(ShopifyApi.AuthTokenServer, []),
      supervisor(ShopifyApi.EventPipe.Supervisor, [%{}])
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ShopifyApi.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
