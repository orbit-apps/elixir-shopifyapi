defmodule ShopifyAPI.Config do
  @moduledoc false

  @offline_tokens [:permanent, :expiring, :exchange_permanent]

  def lookup(key), do: Application.get_env(:shopify_api, key)
  def lookup(key, subkey), do: Application.get_env(:shopify_api, key)[subkey]

  # Which shape of offline token the app acquires, and what `ShopifyAPI.AuthToken.fetch/2` does
  # with a permanent one. `:offline_tokens` takes precedence; when it is unset or `nil`, the
  # older boolean `:expiring` maps `true` to `:expiring` and anything else to `:permanent`.
  @spec offline_tokens() :: :permanent | :expiring | :exchange_permanent
  def offline_tokens do
    case Application.get_env(:shopify_api, :offline_tokens) do
      nil ->
        if Application.get_env(:shopify_api, :expiring) == true, do: :expiring, else: :permanent

      mode when mode in @offline_tokens ->
        mode

      other ->
        raise ArgumentError,
              "invalid :offline_tokens setting #{inspect(other)}, expected one of " <>
                Enum.map_join(@offline_tokens, ", ", &inspect/1)
    end
  end

  # Whether new token requests ask for an expiring token. Tokens that already carry a refresh
  # token are refreshed regardless of this setting.
  @spec expiring?() :: boolean()
  def expiring?, do: offline_tokens() != :permanent

  @spec app_name() :: String.t() | nil
  @spec app_name(Plug.Conn.t(), keyword()) :: String.t() | nil
  def app_name, do: lookup(:app_name)

  def app_name(%Plug.Conn{path_info: path_info}, opts \\ []),
    do: Keyword.get(opts, :app_name) || app_name() || List.last(path_info)
end
