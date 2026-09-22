defmodule ShopifyAPI.TokenConfigSetup do
  @moduledoc """
  Clears the global `:offline_tokens` and `:expiring` settings for one test and restores them
  afterwards. Use as `setup :isolate_token_config` in a module that is not async.
  """

  import ExUnit.Callbacks, only: [on_exit: 1]

  @keys [:offline_tokens, :expiring]

  def isolate_token_config(_context) do
    previous = Map.new(@keys, &{&1, Application.fetch_env(:shopify_api, &1)})
    Enum.each(@keys, &Application.delete_env(:shopify_api, &1))

    on_exit(fn ->
      Enum.each(previous, fn
        {key, {:ok, value}} -> Application.put_env(:shopify_api, key, value)
        {key, :error} -> Application.delete_env(:shopify_api, key)
      end)
    end)

    :ok
  end
end
