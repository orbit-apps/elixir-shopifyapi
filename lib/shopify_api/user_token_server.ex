defmodule ShopifyAPI.UserTokenServer do
  @moduledoc """
  Write-through cache for `ShopifyAPI.UserToken` structs.

  Online tokens are issued per staff member rather than per app, and they expire. One is
  obtained when a user opens the embedded app and is used for requests that must respect that
  user's own permissions. `ShopifyAPI.AuthTokenServer` is the offline counterpart, and
  documents the caching design and the initializer/persistence contract that both servers
  share — only the differences are described here.

  Shopify covers the distinction under
  [Access tokens](https://shopify.dev/docs/apps/build/authentication-authorization/access-tokens).

  ## Storage model

  Identical to `ShopifyAPI.AuthTokenServer` — a public, named ETS table owned by a `GenServer`
  that does nothing but hold it and run the initializer — except that entries are keyed by
  `{shop_name, app_name, associated_user_id}`. One shop has as many tokens as it has staff
  members using the app.

  ## Expiry

  Unlike an offline token, a user token goes stale. `get/3` returns whatever is cached without
  regard to that; `get_valid/3` pipes the result through `validate/1`, which treats a token as
  live while `timestamp + expires_in` has not yet passed:

      user_token.timestamp + user_token.expires_in >= DateTime.to_unix(DateTime.utc_now())

  The comparison is exact — there is no grace period for clock skew between this node and
  Shopify, and nothing renews a token in place. An expired entry stays in the cache until it is
  overwritten by a fresh one or removed with `delete/1`.

  > #### Expired and missing are the same error {: .warning}
  >
  > `validate/1` maps *both* an expired token and a cache miss to
  > `{:error, :invalid_user_token}`, so `get_valid/3` cannot tell them apart. Call `get/3` when
  > you need to distinguish them — it returns `{:error, :user_token_not_found}` for a miss.

  ## Configuration

      config :shopify_api, ShopifyAPI.UserTokenServer,
        initializer: {MyApp.UserToken, :init, []},
        persistence: {MyApp.UserToken, :save, []}

  The callbacks behave exactly as `ShopifyAPI.AuthTokenServer`'s do, including that the
  persistence key is a string — here `"shop_name:app_name:associated_user_id"` from
  `ShopifyAPI.UserToken.create_key/1` — rather than the tuple the table is keyed by.

  Configuring them is optional in a way it is not for offline tokens. A user token is worth
  little beyond the session that produced it, so an app can leave both unset and let the cache
  refill through OAuth, accepting that every restart sends active users back through it.

  ## Removing tokens

  `delete/1` takes a token struct rather than its parts, and `delete_for_shop/1` clears every
  user's token for a shop, which is what an `app/uninstalled` webhook wants. As with the offline
  cache, neither calls the persistence callback — delete from your own storage too.
  """

  use GenServer

  alias ShopifyAPI.Config
  alias ShopifyAPI.UserToken

  @table __MODULE__
  @type t :: UserToken.t()
  @type ok_t :: {:ok, t()}
  @type error_not_found :: {:error, :user_token_not_found}

  @doc """
  Returns every cached token, keyed by `{shop_name, app_name, associated_user_id}`.

  Intended for introspection. Prefer `get/3` or `get_valid/3` in application code.
  """
  @spec all() :: %{optional({String.t(), String.t(), integer()}) => t()}
  def all do
    @table
    |> :ets.tab2list()
    |> Map.new()
  end

  @doc """
  Returns the number of tokens currently cached, expired ones included.
  """
  @spec count() :: integer()
  def count, do: :ets.info(@table, :size)

  @doc """
  Stores a token in the cache and, by default, persists it.

  Pass `false` as the second argument to skip the persistence callback, as the initializer does
  for tokens it has just loaded out of storage.

  ## Examples

      iex> token = %ShopifyAPI.UserToken{shop_name: "shop.myshopify.com", app_name: "my-app", associated_user_id: 1}
      iex> ShopifyAPI.UserTokenServer.set(token, false)
      :ok

  """
  @spec set(UserToken.t()) :: :ok
  @spec set(UserToken.t(), boolean()) :: :ok
  def set(token, should_persist \\ true) when is_struct(token, UserToken) do
    :ets.insert(@table, {{token.shop_name, token.app_name, token.associated_user_id}, token})
    if should_persist, do: do_persist(token)
    :ok
  end

  @doc """
  Fetches a user's token for a shop and app, without checking whether it has expired.

  Use this when a cache miss and an expired token need different handling — `get_valid/3`
  reports both as `{:error, :invalid_user_token}`.

  ## Examples

      iex> token = %ShopifyAPI.UserToken{shop_name: "shop.myshopify.com", app_name: "my-app", associated_user_id: 2}
      iex> ShopifyAPI.UserTokenServer.set(token)
      iex> ShopifyAPI.UserTokenServer.get("shop.myshopify.com", "my-app", 2)
      {:ok, token}

      iex> ShopifyAPI.UserTokenServer.get("unknown.myshopify.com", "my-app", 1)
      {:error, :user_token_not_found}

  """
  @spec get(String.t(), String.t(), integer()) :: ok_t() | error_not_found()
  def get(myshopify_domain, app_name, user_id)
      when is_binary(myshopify_domain) and is_binary(app_name) and is_number(user_id) do
    case :ets.lookup(@table, {myshopify_domain, app_name, user_id}) do
      [{_key, token}] -> {:ok, token}
      [] -> {:error, :user_token_not_found}
    end
  end

  @doc """
  Fetches a user's token for a shop and app, provided it has not expired.

  Returns `{:error, :invalid_user_token}` both when the token has expired and when there is no
  token cached at all. Reach for `get/3` if you need to tell those apart — for instance to
  decide between refreshing and sending the user back through OAuth.

  ## Examples

      iex> token = %ShopifyAPI.UserToken{
      ...>   shop_name: "shop.myshopify.com",
      ...>   app_name: "my-app",
      ...>   associated_user_id: 3,
      ...>   timestamp: DateTime.to_unix(DateTime.utc_now()),
      ...>   expires_in: 86_400
      ...> }
      iex> ShopifyAPI.UserTokenServer.set(token)
      iex> ShopifyAPI.UserTokenServer.get_valid("shop.myshopify.com", "my-app", 3)
      {:ok, token}

      # An hour-long token issued in 2020
      iex> expired = %ShopifyAPI.UserToken{
      ...>   shop_name: "shop.myshopify.com",
      ...>   app_name: "my-app",
      ...>   associated_user_id: 4,
      ...>   timestamp: 1_600_000_000,
      ...>   expires_in: 3600
      ...> }
      iex> ShopifyAPI.UserTokenServer.set(expired)
      iex> ShopifyAPI.UserTokenServer.get_valid("shop.myshopify.com", "my-app", 4)
      {:error, :invalid_user_token}

  """
  @spec get_valid(String.t(), String.t(), integer()) :: ok_t() | {:error, :invalid_user_token}
  def get_valid(myshopify_domain, app_name, user_id),
    do: myshopify_domain |> get(app_name, user_id) |> validate()

  @doc """
  Checks the expiry on a `get/3` result, for piping.

  Takes the result tuple rather than a token, so it composes directly onto `get/3` — which is
  all `get_valid/3` does. A token counts as live while `timestamp + expires_in` is still in the
  future; the comparison allows no margin for clock skew.

  Every input other than a live `{:ok, token}` collapses to `{:error, :invalid_user_token}`,
  including `{:error, :user_token_not_found}`.

  ## Examples

      iex> ShopifyAPI.UserTokenServer.validate({:error, :user_token_not_found})
      {:error, :invalid_user_token}

  """
  @spec validate(ok_t() | error_not_found()) :: ok_t() | {:error, :invalid_user_token}
  def validate({:ok, user_token}) do
    now = DateTime.to_unix(DateTime.utc_now())

    if user_token.timestamp + user_token.expires_in >= now do
      {:ok, user_token}
    else
      {:error, :invalid_user_token}
    end
  end

  def validate(_), do: {:error, :invalid_user_token}

  @doc """
  Returns every cached token for a shop, one per staff member, expired ones included.

  The result is a bare list rather than an ok tuple, and is empty when nothing matches.

  ## Examples

      iex> token = %ShopifyAPI.UserToken{shop_name: "one-user.myshopify.com", app_name: "my-app", associated_user_id: 1}
      iex> ShopifyAPI.UserTokenServer.set(token)
      iex> ShopifyAPI.UserTokenServer.get_for_shop("one-user.myshopify.com")
      [token]

      iex> ShopifyAPI.UserTokenServer.get_for_shop("unknown.myshopify.com")
      []

  """
  @spec get_for_shop(String.t()) :: [t()]
  def get_for_shop(myshopify_domain) when is_binary(myshopify_domain) do
    match_spec = [{{{myshopify_domain, :_, :_}, :"$1"}, [], [:"$1"]}]
    :ets.select(@table, match_spec)
  end

  @doc """
  Returns every cached token issued for an app, across all shops and users.

  Like `get_for_shop/1`, the result is a bare list and is empty when nothing matches.

  ## Examples

      iex> token = %ShopifyAPI.UserToken{shop_name: "shop.myshopify.com", app_name: "my-report-app", associated_user_id: 1}
      iex> ShopifyAPI.UserTokenServer.set(token)
      iex> ShopifyAPI.UserTokenServer.get_for_app("my-report-app")
      [token]

  """
  @spec get_for_app(String.t()) :: [t()]
  def get_for_app(app) when is_binary(app) do
    match_spec = [{{{:_, app, :_}, :"$1"}, [], [:"$1"]}]
    :ets.select(@table, match_spec)
  end

  @doc """
  Removes one user's token from the cache.

  Takes the token struct itself, since the cache key spans three fields — unlike
  `ShopifyAPI.AuthTokenServer.delete/2`, which takes a shop and an app name.

  The persistence callback is not called, so delete from your own storage as well.

  ## Examples

      iex> token = %ShopifyAPI.UserToken{shop_name: "closing.myshopify.com", app_name: "my-app", associated_user_id: 1}
      iex> ShopifyAPI.UserTokenServer.set(token)
      iex> ShopifyAPI.UserTokenServer.delete(token)
      :ok
      iex> ShopifyAPI.UserTokenServer.get_for_shop("closing.myshopify.com")
      []

  """
  @spec delete(UserToken.t()) :: :ok
  def delete(token) do
    :ets.delete(@table, {token.shop_name, token.app_name, token.associated_user_id})
    :ok
  end

  @doc """
  Removes every user's token for a shop from the cache.

  This is what an `app/uninstalled` webhook wants, since a shop that has uninstalled leaves one
  stale token behind per staff member. `ShopifyAPI.AuthTokenServer` has no equivalent — clear
  the offline token with `ShopifyAPI.AuthTokenServer.delete/2` alongside this.

  As with `delete/1`, persisted tokens are untouched.

  ## Examples

      iex> first = %ShopifyAPI.UserToken{shop_name: "gone.myshopify.com", app_name: "my-app", associated_user_id: 1}
      iex> second = %ShopifyAPI.UserToken{shop_name: "gone.myshopify.com", app_name: "my-app", associated_user_id: 2}
      iex> ShopifyAPI.UserTokenServer.set(first)
      iex> ShopifyAPI.UserTokenServer.set(second)
      iex> ShopifyAPI.UserTokenServer.delete_for_shop("gone.myshopify.com")
      :ok
      iex> ShopifyAPI.UserTokenServer.get_for_shop("gone.myshopify.com")
      []

  """
  @spec delete_for_shop(String.t()) :: :ok
  def delete_for_shop(myshopify_domain) when is_binary(myshopify_domain) do
    myshopify_domain |> get_for_shop() |> Enum.each(&delete/1)
    :ok
  end

  @doc """
  Removes every token from the cache, for every shop and user.

  As with `delete/1`, persisted tokens are left alone and the initializer repopulates the cache
  on the next restart.
  """
  @spec drop_all() :: true
  def drop_all, do: :ets.delete_all_objects(@table)

  ## GenServer Callbacks

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @impl GenServer
  def init(:ok) do
    create_table!()
    for token when is_struct(token, UserToken) <- do_initialize(), do: set(token, false)
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

  # Attempts to persist an UserToken if a persistence callback is configured
  defp do_persist(token) when is_struct(token, UserToken) do
    key = UserToken.create_key(token)

    case Config.lookup(__MODULE__, :persistence) do
      {module, function, args} -> apply(module, function, [key, token | args])
      {module, function} -> apply(module, function, [key, token])
      _ -> nil
    end
  end
end
