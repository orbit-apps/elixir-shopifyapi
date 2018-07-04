defmodule ShopifyAPI.EventPipe.Supervisor do
  require Logger
  use Supervisor

  def start_link(opts) do
    Logger.info(fn -> "Starting #{__MODULE__}..." end)
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_) do
    children = []

    Supervisor.init(children, strategy: :one_for_one)
  end
end
