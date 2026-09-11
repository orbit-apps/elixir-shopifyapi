defmodule ShopifyAPI.AuthTokenServer do
  @moduledoc """
  Write-through cache for `ShopifyAPI.AuthToken` structs.

  An offline auth token is written here once, when a shop installs the app, and is read on
  every authenticated request afterwards. This cache sits in front of whatever storage your
  application uses: configure an `:initializer` to load tokens back at boot and a
  `:persistence` callback to write them out. Without them the cache is purely in-memory and
  every token is lost when the application stops.

  ## Storage model

  Tokens are held in a public, named ETS table keyed by `{shop_name, app_name}`. Because the
  table is public, every function in this module runs in the calling process — the
  `GenServer` implements no `handle_call/3` or `handle_cast/2` and is never a bottleneck. It
  exists to own the table and to run the initializer once from `c:GenServer.init/1`.

  The table belongs to that process, so it is destroyed if the server crashes.
  `ShopifyAPI.Supervisor` starts a replacement and the initializer repopulates it; anything
  written with `set/2` but never persisted is gone.

  ## Offline and online tokens

  A `ShopifyAPI.AuthToken` is an *offline* token: it belongs to the app rather than to a user,
  and is what REST and GraphQL calls authenticate with. Per-user *online* tokens are
  `ShopifyAPI.UserToken` structs, cached separately by `ShopifyAPI.UserTokenServer`, and those
  expire and are validated when read. `ShopifyAPI.App.fetch_token/3` decides which of the two
  an OAuth response produces.

  This cache holds both shapes of offline token — permanent and expiring — and treats them
  alike. Nothing here inspects an expiry, evicts, or refreshes; `get/2` hands back whatever is
  cached, live or not. `ShopifyAPI.AuthToken.fetch/2` is the accessor that checks and refreshes,
  and is what application code should read through.

  Shopify documents the distinction under
  [Access tokens](https://shopify.dev/docs/apps/build/authentication-authorization/access-tokens).

  ## Configuration

      config :shopify_api, ShopifyAPI.AuthTokenServer,
        initializer: {MyApp.AuthToken, :init, []},
        persistence: {MyApp.AuthToken, :save, []}

  Both keys are optional. Configuration is read on each call rather than cached, so omitting
  the block entirely — or setting either key to `nil` — disables that half of the behaviour.

  ## Initializer

  The initializer runs once during startup, invoked as `apply(module, function, args)`. The
  configured arguments are passed through exactly as given; nothing is prepended. A
  `{module, function}` tuple is also accepted and is called with no arguments.

  It must return an enumerable of `ShopifyAPI.AuthToken` structs. Anything in that enumerable
  which is not a `ShopifyAPI.AuthToken` struct is silently discarded. Tokens loaded this way
  are not written back out through the persistence callback, and are not checked: a token
  missing part of its credentials is cached as is, where
  `ShopifyAPI.AuthToken.validate_pair/1` would reject it.

  It runs synchronously inside `c:GenServer.init/1`, so the supervisor blocks until it
  returns. List `ShopifyAPI.Supervisor` after anything the initializer depends on, such as
  your `Ecto.Repo`.

  ## Persistence

  The persistence callback is invoked by `set/2` as
  `apply(module, function, [key, token | args])` — the cache key first, the token second, and
  any configured arguments appended.

  The `key` is the string built by `ShopifyAPI.AuthToken.create_key/1`,
  `"shop_name:app_name"`, and not the `{shop_name, app_name}` tuple the table is keyed by.
  Implementations typically ignore it and read `shop_name` and `app_name` off the token.

  The callback runs synchronously, in the calling process — which during installation is
  Shopify's OAuth redirect.

  `set/2` persists *before* it writes to the cache, and treats a failure as fatal: an exception
  from the callback propagates, and an `{:error, _}` return is raised as a
  `ShopifyAPI.TokenPersistenceError`. Every other return value, `nil` included, is a success.

  That error's message gives the reason's shape but not its contents — an atom as is, a struct
  by its module name — because a reason such as a changeset holds the token being written.
  Log the details from inside the callback if you need them.

  > #### A callback that cannot write must raise {: .warning}
  >
  > An expiring token is a pair — access token and refresh token, replaced together. If the
  > cache holds a pair that storage never received, the next refresh replaces both halves and
  > the old pair in storage can no longer refresh. Persisting first means a failure leaves both
  > sides on the old pair.
  >
  > Prefer `c:Ecto.Repo.insert!/2` over `c:Ecto.Repo.insert/2`.

  > #### Deletes are never persisted {: .warning}
  >
  > `delete/2` and `drop_all/0` only clear the cache. Neither calls the persistence callback,
  > so a token left in your own storage is loaded straight back in by the initializer on the
  > next restart. Delete it from both.

  ### Example

  A persistence module backed by Ecto:

      defmodule MyApp.AuthToken do
        alias ShopifyAPI.AuthToken

        def init do
          Enum.map(MyApp.Repo.all(MyApp.Schema.AuthToken), fn row ->
            %AuthToken{
              shop_name: row.shop_name,
              app_name: row.app_name,
              token: row.token,
              plus: row.plus,
              token_expires_at: row.token_expires_at,
              refresh_token: row.refresh_token,
              refresh_token_expires_at: row.refresh_token_expires_at
            }
          end)
        end

        def save(_key, %AuthToken{} = token) do
          %MyApp.Schema.AuthToken{}
          |> MyApp.Schema.AuthToken.changeset(Map.from_struct(token))
          |> MyApp.Repo.insert!(
            on_conflict:
              {:replace,
               [:token, :plus, :token_expires_at, :refresh_token, :refresh_token_expires_at]},
            conflict_target: [:shop_name, :app_name]
          )
        end
      end

  `Map.from_struct/1` is enough here because the schema's field names match the struct's;
  `Ecto.Changeset.cast/4` discards the rest. Conflicting on `[:shop_name, :app_name]` rather
  than on `:shop_name` alone keeps a shop able to install more than one of your apps.

  Every field of the pair is in the `:replace` list. Omitting any of them silently preserves
  stale values, and the token stops working when the old refresh token expires.

  A callback does not have to persist everything it is handed. Matching on `app_name` routes
  several apps' tokens to different storage:

      def save(_key, %AuthToken{app_name: "my-companion-app"} = token), do: store_companion(token)
      def save(_key, token), do: Logger.info("Not persisting a token for \#{token.app_name}")

  ## Handling app uninstalls

  Nothing in this library deletes tokens. Shopify revokes a token when a shop uninstalls the
  app and notifies you through the
  [`app/uninstalled` webhook](https://shopify.dev/docs/api/webhooks), so subscribe to it and
  clear both your storage and this cache, or a reinstall will reuse a dead token:

      def handle_webhook(_app, shop, "app/uninstalled", _payload) do
        MyApp.AuthTokens.delete(shop.domain, MyApp.app_name())
        ShopifyAPI.AuthTokenServer.delete(shop.domain, MyApp.app_name())
      end

  ## Testing

  Pass `false` as the second argument to `set/2` to fill the cache without invoking the
  persistence callback:

      ShopifyAPI.AuthTokenServer.set(%ShopifyAPI.AuthToken{shop_name: shop, app_name: app}, false)

  Or turn both callbacks off for the test environment:

      config :shopify_api, ShopifyAPI.AuthTokenServer, initializer: nil, persistence: nil
  """

  use GenServer

  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.Config

  @table __MODULE__

  @doc """
  Returns every cached token, keyed by `{shop_name, app_name}`.

  The keys are the tuples the table is keyed by, not the `"shop_name:app_name"` strings that
  `ShopifyAPI.AuthToken.create_key/1` builds:

      %{{"shop.myshopify.com", "my-app"} => %ShopifyAPI.AuthToken{}}

  Intended for introspection and debugging. Prefer `get/2`, `get_for_shop/1` or
  `get_for_app/1` in application code.
  """
  @spec all() :: %{optional({String.t(), String.t()}) => AuthToken.t()}
  def all, do: @table |> :ets.tab2list() |> Map.new()

  @doc """
  Returns the number of tokens currently cached.
  """
  @spec count() :: integer()
  def count, do: :ets.info(@table, :size)

  @doc """
  Stores a token, persisting it before it reaches the cache.

  Raises `ShopifyAPI.TokenPersistenceError` if the callback returns `{:error, _}`; an
  exception raised inside the callback propagates untouched. In either case nothing is
  written to the cache.

  Pass `false` as the second argument to update the cache alone, leaving the persistence
  callback uncalled. That is what the initializer does with the tokens it loads, since they
  came out of storage to begin with, and it is usually what you want in tests.

  Note that the default differs from `ShopifyAPI.ShopServer.set/2`, which does not persist
  unless asked to.

  ## Examples

      iex> token = %ShopifyAPI.AuthToken{shop_name: "shop.myshopify.com", app_name: "my-app"}
      iex> ShopifyAPI.AuthTokenServer.set(token, false)
      :ok

  """
  @spec set(AuthToken.t()) :: :ok
  @spec set(AuthToken.t(), boolean()) :: :ok
  def set(token, should_persist \\ true) when is_struct(token, AuthToken) do
    if should_persist, do: persist!(token)
    :ets.insert(@table, {{token.shop_name, token.app_name}, token})
    :ok
  end

  @doc """
  Fetches whatever token is cached for a shop and app, expired or not.

  A bare cache read — does not check expiry or refresh. Use `ShopifyAPI.AuthToken.fetch/2`
  when you need a usable token.

  ## Examples

      iex> token = %ShopifyAPI.AuthToken{shop_name: "shop.myshopify.com", app_name: "my-app"}
      iex> ShopifyAPI.AuthTokenServer.set(token)
      iex> ShopifyAPI.AuthTokenServer.get("shop.myshopify.com", "my-app")
      {:ok, token}

      # Assuming nothing has been stored for the shop
      iex> ShopifyAPI.AuthTokenServer.get("unknown.myshopify.com", "my-app")
      {:error, :not_found}

  """
  @spec get(String.t(), String.t()) :: AuthToken.ok_t() | AuthToken.not_found()
  def get(shop, app) when is_binary(shop) and is_binary(app) do
    case :ets.lookup(@table, {shop, app}) do
      [{_key, token}] -> {:ok, token}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Returns every cached token belonging to a shop, across all apps.

  The result is a bare list rather than an ok tuple, and is empty when the shop has no cached
  tokens.

  ## Examples

      iex> token = %ShopifyAPI.AuthToken{shop_name: "one-app.myshopify.com", app_name: "my-app"}
      iex> ShopifyAPI.AuthTokenServer.set(token)
      iex> ShopifyAPI.AuthTokenServer.get_for_shop("one-app.myshopify.com")
      [token]

      iex> ShopifyAPI.AuthTokenServer.get_for_shop("unknown.myshopify.com")
      []

  """
  @spec get_for_shop(String.t()) :: [AuthToken.t()]
  def get_for_shop(shop) when is_binary(shop) do
    match_spec = [{{{shop, :_}, :"$1"}, [], [:"$1"]}]
    :ets.select(@table, match_spec)
  end

  @doc """
  Returns every cached token issued for an app, across all shops.

  Like `get_for_shop/1`, the result is a bare list and is empty when nothing matches.

  ## Examples

      iex> token = %ShopifyAPI.AuthToken{shop_name: "shop.myshopify.com", app_name: "my-report-app"}
      iex> ShopifyAPI.AuthTokenServer.set(token)
      iex> ShopifyAPI.AuthTokenServer.get_for_app("my-report-app")
      [token]

  """
  @spec get_for_app(String.t()) :: [AuthToken.t()]
  def get_for_app(app) when is_binary(app) do
    match_spec = [{{{:_, app}, :"$1"}, [], [:"$1"]}]
    :ets.select(@table, match_spec)
  end

  @doc """
  Removes a shop's token for an app from the cache.

  Only the cache is touched — the persistence callback is not called. A token still sitting in
  your own storage is loaded back in by the initializer on the next restart, so delete it
  there too. See the module documentation on handling app uninstalls.

  ## Examples

      iex> token = %ShopifyAPI.AuthToken{shop_name: "closing.myshopify.com", app_name: "my-app"}
      iex> ShopifyAPI.AuthTokenServer.set(token)
      iex> ShopifyAPI.AuthTokenServer.delete("closing.myshopify.com", "my-app")
      :ok
      iex> ShopifyAPI.AuthTokenServer.get_for_shop("closing.myshopify.com")
      []

  """
  @spec delete(String.t(), String.t()) :: :ok
  def delete(shop_name, app) do
    :ets.delete(@table, {shop_name, app})
    :ok
  end

  @doc """
  Removes every token from the cache.

  As with `delete/2`, persisted tokens are left alone, so the initializer repopulates the
  cache on the next restart.
  """
  @spec drop_all() :: true
  def drop_all, do: :ets.delete_all_objects(@table)

  ## GenServer Callbacks

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @impl GenServer
  def init(:ok) do
    create_table!()
    for %AuthToken{} = token <- do_initialize(), do: set(token, false)
    {:ok, :no_state}
  end

  ## Private Helpers

  defp create_table! do
    :ets.new(@table, [
      :set,
      :public,
      :named_table,
      read_concurrency: true
    ])
  end

  # Calls a configured initializer to obtain a list of AuthTokens.
  defp do_initialize do
    case Config.lookup(__MODULE__, :initializer) do
      {module, function, args} -> apply(module, function, args)
      {module, function} -> apply(module, function, [])
      _ -> []
    end
  end

  # Persists an AuthToken via the configured callback, raising on failure.
  defp persist!(token) when is_struct(token, AuthToken) do
    key = AuthToken.create_key(token)

    result =
      case Config.lookup(__MODULE__, :persistence) do
        {module, function, args} -> apply(module, function, [key, token | args])
        {module, function} -> apply(module, function, [key, token])
        _ -> :ok
      end

    case result do
      {:error, reason} ->
        raise ShopifyAPI.TokenPersistenceError,
          message:
            "Could not persist auth token for #{key}: " <>
              "callback returned {:error, #{describe_reason(reason)}}"

      _ ->
        :ok
    end
  end

  # Names the shape of a persistence failure but not its contents: a reason such as an Ecto
  # changeset holds the token being written, and this message reaches logs and error trackers.
  defp describe_reason(reason) when is_atom(reason), do: inspect(reason)
  defp describe_reason(%module{}), do: "%#{inspect(module)}{}"
  defp describe_reason(_reason), do: "_"
end
