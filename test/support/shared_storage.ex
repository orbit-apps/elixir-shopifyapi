defmodule ShopifyAPI.SharedStorage do
  @moduledoc """
  Token storage shared with another application, for tests of the `get` persistence callback.

  Held in an Agent passed as the callback's configured argument, so background tasks can reach
  it. Use as `setup :use_shared_storage` in a module that is not async; it adds `:storage` to
  the context, and `put/2` stands in for the other application writing a pair.
  """

  import ExUnit.Callbacks, only: [on_exit: 1, start_supervised!: 1]

  alias ShopifyAPI.AuthTokenServer

  def get(shop_name, app_name, agent) do
    case Agent.get(agent, &Map.get(&1, {shop_name, app_name})) do
      nil -> {:error, :not_found}
      token -> {:ok, token}
    end
  end

  def put(agent, token),
    do: Agent.update(agent, &Map.put(&1, {token.shop_name, token.app_name}, token))

  def use_shared_storage(_context) do
    storage = start_supervised!({Agent, fn -> %{} end})
    previous = Application.get_env(:shopify_api, AuthTokenServer)

    Application.put_env(:shopify_api, AuthTokenServer,
      persistence: [get: {__MODULE__, :get, [storage]}]
    )

    on_exit(fn ->
      if previous do
        Application.put_env(:shopify_api, AuthTokenServer, previous)
      else
        Application.delete_env(:shopify_api, AuthTokenServer)
      end
    end)

    {:ok, storage: storage}
  end
end
