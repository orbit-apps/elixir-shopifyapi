defmodule ShopifyAPI.CacheSupervisor do
  @moduledoc """
  The CacheSupervisor provides a convenient way to monitor, control, and start all the ShopifyAPI cache servers.

  ## Using

  Include the CacheSupervisor in your applications children after any dependencies, ie Ecto.

  ```elixir
  def start(_type, _args) do
    # Define workers and child supervisors to be supervised
    children = [
      MyApp.Repo,
      ShopifyAPI.CacheSupervisor
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
  ```
  """
  use Supervisor

  def start_link(arg), do: Supervisor.start_link(__MODULE__, arg, name: __MODULE__)

  @impl true
  def init(_arg) do
    children = [
      ShopifyAPI.ShopServer,
      ShopifyAPI.AppServer,
      ShopifyAPI.AuthTokenServer
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
