defmodule ShopifyAPI.Config do
  @moduledoc false

  def lookup(key), do: Application.get_env(:shopify_api, key)
  def lookup(key, subkey), do: Application.get_env(:shopify_api, key)[subkey]

  @spec app_name() :: String.t() | nil
  @spec app_name(Plug.Conn.t(), keyword()) :: String.t() | nil
  def app_name, do: lookup(:app_name)

  def app_name(%Plug.Conn{path_info: path_info}, opts \\ []),
    do: Keyword.get(opts, :app_name) || app_name() || List.last(path_info)
end
