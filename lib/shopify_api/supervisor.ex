defmodule ShopifyAPI.Supervisor do
  @moduledoc """
  This Supervisor maintains a set of ShopifyAPI servers, used for caching commonly-used data such as Shop, App, and AuthToken structs.

  ## Using

  Include the Supervisor in your applications supervision tree after any dependencies (such as Ecto):

      def start(_type, _args) do
        children = [
          MyApp.Repo,
          ShopifyAPI.Supervisor
        ]

        Supervisor.start_link(children, strategy: :one_for_one)
      end
  """

  use Supervisor

  alias ShopifyAPI.AppServer
  alias ShopifyAPI.AuthTokenServer
  alias ShopifyAPI.ShopServer

  def start_link(_opts) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl Supervisor
  def init(:ok) do
    children = [AppServer, AuthTokenServer, ShopServer]
    Supervisor.init(children, strategy: :one_for_one)
  end
end
