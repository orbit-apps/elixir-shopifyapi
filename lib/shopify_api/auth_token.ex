defmodule ShopifyAPI.AuthToken do
  @moduledoc """
  An offline access token, authorizing an app to act on a shop's behalf.

  Offline tokens belong to the app rather than to a user, which makes them what REST and
  GraphQL calls authenticate with. They are obtained during installation and cached by
  `ShopifyAPI.AuthTokenServer`, which is also where the storage callbacks that outlive a
  restart are configured.

  ## Expiring and permanent tokens

  Shopify issues offline tokens in two shapes, and this struct models both. A *permanent*
  token never expires: `refresh_token` is `nil` and neither expiry is set. An *expiring*
  token lives for an hour and arrives with a `refresh_token`; refreshing replaces both at
  once.

  A `nil` `refresh_token` distinguishes the two throughout this library. `fetch/2` returns a
  token ready to use — refreshing an expiring one if needed, returning a permanent one as is.

  Shopify has required expiring tokens of new public apps since April 2026 and stops
  accepting permanent ones on 1 January 2027. See
  [Offline access tokens](https://shopify.dev/docs/apps/build/authentication-authorization/access-tokens/offline-access-tokens).

  The online, per-user counterpart is `ShopifyAPI.UserToken`. Shopify covers both in
  [Access tokens](https://shopify.dev/docs/apps/build/authentication-authorization/access-tokens).
  """

  @derive {Jason.Encoder,
           only: [
             :code,
             :app_name,
             :shop_name,
             :token,
             :timestamp,
             :plus,
             :token_expires_at,
             :refresh_token,
             :refresh_token_expires_at
           ]}
  @derive {Inspect, except: [:code, :token, :refresh_token]}
  defstruct code: "",
            app_name: "",
            shop_name: "",
            token: "",
            timestamp: 0,
            plus: false,
            token_expires_at: nil,
            refresh_token: nil,
            refresh_token_expires_at: nil

  @typedoc """
      Type that represents a Shopify Auth Token with

        - app_name corresponding to %ShopifyAPI.App{name: app_name}
        - shop_name corresponding to %ShopifyAPI.Shop{domain: shop_name}

  The three nullable fields are set together or not at all: they are populated for an
  expiring token and `nil` for a permanent one. `validate_pair/1` checks this.
  """
  @type t :: %__MODULE__{
          code: String.t(),
          app_name: String.t(),
          shop_name: String.t(),
          token: String.t(),
          timestamp: integer(),
          plus: boolean(),
          token_expires_at: DateTime.t() | nil,
          refresh_token: String.t() | nil,
          refresh_token_expires_at: DateTime.t() | nil
        }
  @type ok_t :: {:ok, t()}

  @typedoc "No token cached for this shop and app."
  @type not_found :: {:error, :not_found}

  @typedoc "Token exists but its refresh token has expired; a new token must be obtained."
  @type needs_reacquisition :: {:error, :needs_reacquisition}

  @typedoc "Every error `fetch/2` can return."
  @type fetch_error :: not_found() | needs_reacquisition()

  @typedoc "The result of `fetch/2`."
  @type fetch_result :: ok_t() | fetch_error()

  @typedoc "The result of `status/2`: the same three outcomes without the token."
  @type status :: :ok | :needs_reacquisition | :not_found

  require Logger

  alias ShopifyAPI.App
  alias ShopifyAPI.AuthTokenServer
  alias ShopifyAPI.Refresh

  @doc """
  Returns a usable token for a shop and app, refreshing if needed.

  A permanent token is returned as is. An expiring token is checked against
  `ShopifyAPI.Refresh.threshold/0`:

    - **Above the threshold** — returned immediately, no refresh.
    - **Below the threshold** — returned immediately, background refresh starts.
    - **Expired** — caller waits for a refresh before receiving the new token.

  Returns `{:error, :not_found}` when nothing is cached, and
  `{:error, :needs_reacquisition}` when the token's refresh token has expired — a new token
  must be obtained via OAuth or token exchange. All other failures (assumed to be transient)
  raise.

  ## Examples

      iex> token = %ShopifyAPI.AuthToken{shop_name: "fetch.myshopify.com", app_name: "my-app"}
      iex> ShopifyAPI.AuthTokenServer.set(token, false)
      iex> ShopifyAPI.AuthToken.fetch("fetch.myshopify.com", "my-app")
      {:ok, token}

      # Assuming nothing has been stored for the shop
      iex> ShopifyAPI.AuthToken.fetch("unknown.myshopify.com", "my-app")
      {:error, :not_found}

  """
  @spec fetch(String.t(), String.t()) :: fetch_result()
  def fetch(myshopify_domain, app_name)
      when is_binary(myshopify_domain) and is_binary(app_name) do
    with {:ok, token} <- AuthTokenServer.get(myshopify_domain, app_name) do
      resolve(token)
    end
  end

  # A permanent token: nothing to check and nothing that could refresh it.
  #
  # TODO(2026-12-01): return `{:error, :needs_reacquisition}` here once every shop is migrated.
  # Shopify stops accepting permanent tokens on 2027-01-01, after which this hands back a token
  # the Admin API answers 403. Change the branch rather than deleting it — without it a permanent
  # token falls through to the expiring path and raises on a refresh it has no token for.
  defp resolve(%__MODULE__{refresh_token: nil} = token), do: {:ok, token}

  defp resolve(%__MODULE__{} = token) do
    now = DateTime.utc_now()
    remaining = remaining_ms(token.token_expires_at, now)
    refresh_dead? = dead?(token.refresh_token_expires_at, now)

    cond do
      remaining > Refresh.threshold() ->
        {:ok, token}

      # Still valid — return it, and start a background refresh if the refresh token is alive.
      remaining > 0 ->
        unless refresh_dead?, do: Refresh.run_in_background(token)
        {:ok, token}

      refresh_dead? ->
        Logger.debug(
          "#{__MODULE__} refresh token for #{create_key(token)} expired " <>
            "#{token.refresh_token_expires_at}, needs new token"
        )

        {:error, :needs_reacquisition}

      true ->
        Refresh.await_or_run(token)
    end
  end

  @doc """
  Checks whether a shop's token can still serve API calls — essentially whether
  the refresh token is still alive.

  A cache read only — no Shopify round trip and no refresh.

    - `:ok` — permanent, live, or expired with a live refresh token.
    - `:needs_reacquisition` — both halves expired; a new token must be obtained.
    - `:not_found` — nothing cached for this shop and app.

  ## Examples

      iex> token = %ShopifyAPI.AuthToken{shop_name: "status.myshopify.com", app_name: "my-app"}
      iex> ShopifyAPI.AuthTokenServer.set(token, false)
      iex> ShopifyAPI.AuthToken.status("status.myshopify.com", "my-app")
      :ok

      iex> ShopifyAPI.AuthToken.status("unknown.myshopify.com", "my-app")
      :not_found

  """
  @spec status(String.t(), String.t()) :: status()
  def status(myshopify_domain, app_name)
      when is_binary(myshopify_domain) and is_binary(app_name) do
    case AuthTokenServer.get(myshopify_domain, app_name) do
      {:error, :not_found} ->
        :not_found

      {:ok, %__MODULE__{refresh_token: nil}} ->
        :ok

      {:ok, token} ->
        now = DateTime.utc_now()

        if remaining_ms(token.token_expires_at, now) <= 0 and
             dead?(token.refresh_token_expires_at, now) do
          :needs_reacquisition
        else
          :ok
        end
    end
  end

  # A missing expiry is treated as expired — refreshing repairs the record.
  defp remaining_ms(nil, _now), do: 0

  defp remaining_ms(%DateTime{} = expires_at, now),
    do: DateTime.diff(expires_at, now, :millisecond)

  # A missing refresh-token expiry is not treated as dead — let Shopify decide.
  defp dead?(nil, _now), do: false
  defp dead?(%DateTime{} = expires_at, now), do: DateTime.compare(expires_at, now) != :gt

  @spec create_key(t()) :: String.t()
  def create_key(%__MODULE__{shop_name: shop, app_name: app}), do: create_key(shop, app)

  @spec create_key(String.t(), String.t()) :: String.t()
  def create_key(shop, app), do: "#{shop}:#{app}"

  @doc """
  Builds a permanent token from an access token string.

  Carries no expiry and no refresh token. See `from_auth_request/4` for the constructor that
  handles expiring tokens.

  ## Examples

      iex> app = %ShopifyAPI.App{name: "my-app"}
      iex> token = ShopifyAPI.AuthToken.new(app, "shop.myshopify.com", "auth-code", "shpat_abc")
      iex> token.refresh_token
      nil

  """
  @spec new(App.t(), String.t(), String.t(), String.t()) :: t()
  def new(app, myshopify_domain, auth_code, token) do
    %__MODULE__{
      app_name: app.name,
      shop_name: myshopify_domain,
      code: auth_code,
      token: token
    }
  end

  @doc """
  Builds a token from a parsed access token response.

  Populates the refresh token and both expiries for an expiring token; leaves all three `nil`
  for a permanent one. Expiries are computed from the response's `expires_in` and
  `refresh_token_expires_in` fields, which are durations in seconds.

  ## Examples

      iex> app = %ShopifyAPI.App{name: "my-app"}
      iex> attrs = %{
      ...>   "access_token" => "shpat_abc",
      ...>   "expires_in" => 3600,
      ...>   "refresh_token" => "shprt_xyz",
      ...>   "refresh_token_expires_in" => 7_775_999
      ...> }
      iex> token = ShopifyAPI.AuthToken.from_auth_request(app, "shop.myshopify.com", attrs)
      iex> token.refresh_token
      "shprt_xyz"
      iex> DateTime.compare(token.token_expires_at, DateTime.utc_now())
      :gt

      # A permanent token response carries none of the three
      iex> app = %ShopifyAPI.App{name: "my-app"}
      iex> token = ShopifyAPI.AuthToken.from_auth_request(app, "shop.myshopify.com", %{"access_token" => "shpat_abc"})
      iex> {token.refresh_token, token.token_expires_at, token.refresh_token_expires_at}
      {nil, nil, nil}

  """
  @spec from_auth_request(App.t(), String.t(), String.t(), map()) :: t()
  def from_auth_request(app, myshopify_domain, code \\ "", attrs) when is_struct(app, App) do
    now = DateTime.utc_now()

    %__MODULE__{
      app_name: app.name,
      shop_name: myshopify_domain,
      code: code,
      token: attrs["access_token"],
      token_expires_at: expires_at(now, attrs["expires_in"]),
      refresh_token: attrs["refresh_token"],
      refresh_token_expires_at: expires_at(now, attrs["refresh_token_expires_in"])
    }
  end

  @doc """
  Swaps a refreshed credential set into the token it renewed.

  Replaces the access token, refresh token and both expiries — the latter computed from the
  `expires_in` and `refresh_token_expires_in` durations, in seconds. All other fields —
  `plus`, `shop_name`, `app_name` — are kept from the original, since a refresh grant returns
  only credentials.

  ## Examples

      iex> token = %ShopifyAPI.AuthToken{shop_name: "shop.myshopify.com", app_name: "my-app", plus: true}
      iex> refreshed = ShopifyAPI.AuthToken.apply_refresh(token, "shpat_new", 3600, "shprt_new", 7_775_999)
      iex> {refreshed.token, refreshed.plus}
      {"shpat_new", true}

  """
  @spec apply_refresh(t(), String.t(), pos_integer(), String.t(), pos_integer()) :: t()
  def apply_refresh(
        %__MODULE__{} = token,
        token_value,
        expires_in,
        refresh_token,
        refresh_token_expires_in
      ) do
    now = DateTime.utc_now()

    %__MODULE__{
      token
      | token: token_value,
        token_expires_at: expires_at(now, expires_in),
        refresh_token: refresh_token,
        refresh_token_expires_at: expires_at(now, refresh_token_expires_in)
    }
  end

  @doc """
  Checks that a token's credentials are complete and consistent.

  Every token needs an access token in `token`. A permanent token has none of
  `token_expires_at`, `refresh_token` and `refresh_token_expires_at`; an expiring token has
  all three, and its refresh token must outlive its access token — see
  `refresh_outlives_access?/1`.

  Returns `{:error, :incomplete_pair}` when the access token is missing, when only some of the
  three are set, or when one holds a value of the wrong type, and
  `{:error, :refresh_token_expires_first}` when the refresh token expires no later than the
  access token.

  Tokens from `ShopifyAPI.App.fetch_token/3` and
  `ShopifyAPI.AuthRequest.request_offline_access_token/3` have already passed this check.
  `ShopifyAPI.AuthRequest.refresh_offline_access_token/2` holds its response to a stricter
  rule of its own, since a refresh must always return a pair. Tokens loaded by the
  `ShopifyAPI.AuthTokenServer` initializer are cached as given; call it there to catch a row
  missing part of its credentials.

  ## Examples

      iex> ShopifyAPI.AuthToken.validate_pair(%ShopifyAPI.AuthToken{token: "shpat_abc"})
      :ok

      iex> token = %ShopifyAPI.AuthToken{
      ...>   token: "shpat_abc",
      ...>   token_expires_at: ~U[2026-09-11 13:00:00Z],
      ...>   refresh_token: "shprt_xyz",
      ...>   refresh_token_expires_at: ~U[2026-12-10 13:00:00Z]
      ...> }
      iex> ShopifyAPI.AuthToken.validate_pair(token)
      :ok
      iex> ShopifyAPI.AuthToken.validate_pair(%{token | refresh_token: nil})
      {:error, :incomplete_pair}

  """
  @spec validate_pair(t()) :: :ok | {:error, :incomplete_pair | :refresh_token_expires_first}
  def validate_pair(%__MODULE__{
        token_expires_at: nil,
        refresh_token: nil,
        refresh_token_expires_at: nil,
        token: auth_token
      })
      when is_binary(auth_token),
      do: :ok

  def validate_pair(
        %__MODULE__{
          refresh_token_expires_at: %DateTime{},
          refresh_token: refresh_token,
          token_expires_at: %DateTime{},
          token: auth_token
        } = token
      )
      when is_binary(refresh_token) and is_binary(auth_token) do
    if refresh_outlives_access?(token), do: :ok, else: {:error, :refresh_token_expires_first}
  end

  def validate_pair(%__MODULE__{}), do: {:error, :incomplete_pair}

  @doc """
  Returns whether a token's refresh token expires after its access token.

  When it does not, nothing is left to renew the access token with once it expires. A token
  without both expiries, a permanent one included, returns `false`.

  ## Examples

      iex> token = %ShopifyAPI.AuthToken{
      ...>   token_expires_at: ~U[2026-09-11 13:00:00Z],
      ...>   refresh_token_expires_at: ~U[2026-12-10 13:00:00Z]
      ...> }
      iex> ShopifyAPI.AuthToken.refresh_outlives_access?(token)
      true

  """
  @spec refresh_outlives_access?(t()) :: boolean()
  def refresh_outlives_access?(%__MODULE__{
        token_expires_at: %DateTime{} = token_expires_at,
        refresh_token_expires_at: %DateTime{} = refresh_token_expires_at
      }),
      do: DateTime.after?(refresh_token_expires_at, token_expires_at)

  def refresh_outlives_access?(%__MODULE__{}), do: false

  defp expires_at(_now, nil), do: nil
  defp expires_at(now, seconds) when is_integer(seconds), do: DateTime.add(now, seconds, :second)
end
