defmodule ShopifyAPI.JWTSessionToken do
  @moduledoc """
  Validates Shopify session tokens and exchanges them for access tokens.

  An embedded app is handed a
  [session token](https://shopify.dev/docs/apps/build/authentication-authorization/session-tokens/set-up-session-tokens)
  on every request from App Bridge, normally as an `Authorization: Bearer` header. It is a
  short-lived JWT signed with the app's client secret that identifies the shop and the staff
  member, but grants no API access of its own.

  `get_offline_token/2` and `get_user_token/2` turn one into an access token that does. Both
  read from the relevant cache first and fall back to
  [token exchange](https://shopify.dev/docs/apps/build/authentication-authorization/access-tokens/token-exchange)
  when there is nothing usable there, so an embedded app can obtain its tokens without ever
  sending a merchant through the OAuth redirect that `ShopifyAPI.Router` implements.

  ## Reading a session token

  `verify/2` checks the signature; the remaining readers pull claims out of the decoded JWT:
  `app/1` resolves the `aud` claim to a `ShopifyAPI.App`, `myshopify_domain/1` the `dest`
  claim, and `user_id/1` the `sub` claim.

  ## Exchanging a session token

  `get_offline_token/2` looks in `ShopifyAPI.AuthTokenServer` and exchanges on a miss.
  `get_user_token/2` looks in `ShopifyAPI.UserTokenServer` with `get_valid/3`, so it also
  exchanges when the cached token has expired. Both store what they receive, and neither
  refreshes a token in place.

  > #### The post-login hook runs unsupervised {: .warning}
  >
  > After a successful exchange these functions fire the `ShopifyAPI.Shop` `post_login` hook
  > inside a `Task.async/1` that is never awaited. The task is linked to the calling process, so
  > an exception in your hook takes down the request that triggered it, and its reply is left
  > sitting in that process's mailbox. Keep the hook total, or hand its work to a job queue.
  """
  require Logger

  @doc """
  Verifies a session token's signature against an app's client secret.

  Returns JOSE's three-element result rather than an ok tuple, so match on `{true, jwt, _jws}`
  to accept a token and treat everything else as a rejection.
  """
  @spec verify(String.t(), String.t()) ::
          {valid? :: boolean(), jwt :: JOSE.JWT.t(), jws :: JOSE.JWS.t()}
  def verify(token, client_secret) do
    jwk = JOSE.JWK.from_oct(client_secret)
    JOSE.JWT.verify_strict(jwk, ["HS256"], token)
  end

  @doc """
  Resolves a session token's `aud` claim to the `ShopifyAPI.App` it was issued for.

  > #### A raw token is read unverified {: .warning}
  >
  > Given a binary this peeks at the JWT payload without checking its signature, because the
  > app it names is what supplies the secret needed to check it. Treat the result as untrusted
  > until `verify/2` has passed.
  """
  @spec app(JOSE.JWT.t() | String.t()) :: {:ok, ShopifyAPI.App.t()} | {:error, any()}
  def app(%JOSE.JWT{fields: %{"aud" => client_id}}) do
    case ShopifyAPI.AppServer.get_by_client_id(client_id) do
      {:ok, _} = resp -> resp
      _ -> {:error, "Audience claim is not a valid App clientId."}
    end
  end

  def app(token) when is_binary(token), do: token |> JOSE.JWT.peek_payload() |> app()

  @doc """
  Returns the myshopify domain a session token was issued for, from its `dest` claim.
  """
  @spec myshopify_domain(JOSE.JWT.t()) :: {:ok, String.t()} | {:error, any()}
  def myshopify_domain(%JOSE.JWT{fields: %{"dest" => shop_url}}) do
    shop_url
    |> URI.parse()
    |> Map.get(:host)
    |> case do
      shop_name when is_binary(shop_name) -> {:ok, shop_name}
      _ -> {:error, "Shop name not found"}
    end
  end

  def myshopify_domain(_), do: {:error, "Invalid user token or shop name not found"}

  @doc """
  Returns the id of the staff member a session token was issued for, from its `sub` claim.

  This is the `associated_user_id` that `ShopifyAPI.UserTokenServer` keys online tokens by.
  """
  @spec user_id(JOSE.JWT.t()) :: {:ok, integer()} | {:error, any()}
  def user_id(%JOSE.JWT{fields: %{"sub" => user_id}}),
    do: {:ok, String.to_integer(user_id)}

  def user_id(_),
    do: {:error, "Invalid user token or no id"}

  @doc """
  Returns the shop's offline token, exchanging the session token for one if the cache has none.

  Takes the decoded JWT and the raw token string it came from: the first names the shop and
  app, the second is what Shopify wants as the subject of an exchange. A freshly exchanged
  token is written to `ShopifyAPI.AuthTokenServer` by
  `ShopifyAPI.AuthRequest.request_offline_access_token/3` before it is returned, and the
  `post_login` hook fires.

  This is the token-exchange equivalent of installing through `ShopifyAPI.Router`.
  """
  @spec get_offline_token(JOSE.JWT.t(), String.t()) ::
          {:ok, ShopifyAPI.AuthToken.t()}
          | {:error, :invalid_session_token}
          | {:error, :failed_fetching_offline_token}
  def get_offline_token(%JOSE.JWT{} = jwt, token) do
    with {:ok, myshopify_domain} <- myshopify_domain(jwt),
         {:ok, app} <- app(jwt) do
      case ShopifyAPI.AuthTokenServer.get(myshopify_domain, app.name) do
        {:ok, _} = resp ->
          resp

        {:error, _} ->
          Logger.warning("No token found, exchanging for new")

          case ShopifyAPI.AuthRequest.request_offline_access_token(app, myshopify_domain, token) do
            {:ok, token} ->
              fire_post_login_hook(token)
              {:ok, token}

            error ->
              error
          end
      end
    else
      error ->
        Logger.warning("failed getting required informatio from the JWT #{inspect(error)}")
        {:error, :invalid_session_token}
    end
  end

  @doc """
  Returns the staff member's online token, exchanging the session token for one if needed.

  The online counterpart of `get_offline_token/2`. Because it reads through
  `ShopifyAPI.UserTokenServer.get_valid/3`, it exchanges for a new token when the cached one
  has expired as well as when there is none — which is how an expiring token is renewed here.
  """
  @spec get_user_token(JOSE.JWT.t(), String.t()) ::
          {:ok, ShopifyAPI.UserToken.t()}
          | {:error, :invalid_session_token}
          | {:error, :failed_fetching_online_token}
  def get_user_token(%JOSE.JWT{} = jwt, token) do
    with {:ok, myshopify_domain} <- myshopify_domain(jwt),
         {:ok, app} <- app(jwt),
         {:ok, user_id} <- user_id(jwt) do
      case ShopifyAPI.UserTokenServer.get_valid(myshopify_domain, app.name, user_id) do
        {:ok, _} = resp ->
          resp

        {:error, :invalid_user_token} ->
          Logger.debug("Expired or no user token found, exchanging for new")

          case ShopifyAPI.AuthRequest.request_online_access_token(app, myshopify_domain, token) do
            {:ok, user_token} ->
              fire_post_login_hook(user_token)
              {:ok, user_token}

            error ->
              error
          end
      end
    else
      error ->
        Logger.warning("failed getting required informatio from the JWT #{inspect(error)}")
        {:error, :invalid_session_token}
    end
  end

  defp fire_post_login_hook(user_token),
    do: Task.async(fn -> ShopifyAPI.Shop.post_login(user_token) end)
end
