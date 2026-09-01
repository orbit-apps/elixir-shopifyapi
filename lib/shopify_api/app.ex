defmodule ShopifyAPI.App do
  @moduledoc """
  A Shopify app's identity and OAuth credentials.

  Apps are the root of most things in this library: a token belongs to a shop *and* an app, the
  client secret verifies session tokens and webhook signatures, and the scopes decide what a
  token may do. `ShopifyAPI.AppServer` caches these structs and is where they are loaded from
  your own storage.

  ## Fields

    - `:name` — how this library refers to the app; the `app_name` on every token, and the name
      appended to webhook URLs
    - `:client_id` — the app's API key, which Shopify sends as the `aud` claim of a session
      token and which `ShopifyAPI.AppServer.get_by_client_id/1` looks apps up by
    - `:client_secret` — signs session tokens and webhook HMACs, and authenticates token
      requests
    - `:auth_redirect_uri` — where Shopify returns the merchant after they authorize; must match
      one of the redirect URLs configured in the Partner dashboard
    - `:nonce` — the `state` value round-tripped through OAuth and checked by
      `ShopifyAPI.Router`
    - `:scope` — the comma-separated access scopes requested at install
  """
  @derive {Jason.Encoder,
           only: [:name, :client_id, :client_secret, :auth_redirect_uri, :nonce, :scope]}
  defstruct name: "",
            client_id: "",
            client_secret: "",
            auth_redirect_uri: "",
            nonce: "",
            scope: ""

  @typedoc """
  Type that represents a Shopify App
  """
  @type t :: %__MODULE__{
          name: String.t(),
          client_id: String.t(),
          client_secret: String.t(),
          auth_redirect_uri: String.t(),
          nonce: String.t(),
          scope: String.t()
        }

  require Logger

  alias ShopifyAPI.AuthRequest
  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.JSONSerializer
  alias ShopifyAPI.UserToken

  @doc """
  Exchanges an OAuth authorization code for a token struct.

  Called once the merchant has authorized the app and Shopify has redirected back with a
  `code`. Wraps `ShopifyAPI.AuthRequest.post/3` and parses the response into whichever token
  Shopify issued: a `ShopifyAPI.UserToken` when the response carries an `associated_user`,
  otherwise a `ShopifyAPI.AuthToken`. Which one you get is decided by the app's access mode,
  not by this call.

  Neither the token nor the shop is cached here — `ShopifyAPI.Router` does that with the
  result. The returned token has no `timestamp`; the router fills it in from the OAuth
  callback's query parameters.
  """
  @spec fetch_token(__MODULE__.t(), String.t(), String.t()) ::
          UserToken.ok_t() | AuthToken.ok_t() | {:error, String.t()}
  def fetch_token(app, domain, auth_code) when is_struct(app, __MODULE__) do
    case AuthRequest.post(app, domain, auth_code) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        Logger.info("#{__MODULE__} [#{domain}] fetched token")
        body |> JSONSerializer.decode!() |> create_token(app, domain, auth_code)

      {:ok, %HTTPoison.Response{} = response} ->
        Logger.warning("#{__MODULE__} fetching token code: #{response.status_code}")
        {:error, response.status_code}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.warning("#{__MODULE__} error fetching token: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp create_token(json, app, domain, auth_code)
       when is_map_key(json, "associated_user") and is_map_key(json, "access_token") do
    Logger.debug("online token")
    {:ok, UserToken.from_auth_request(app, domain, auth_code, json)}
  end

  defp create_token(%{"access_token" => token}, app, domain, auth_code) do
    Logger.debug("offline token")
    {:ok, AuthToken.new(app, domain, auth_code, token)}
  end

  defp create_token(_, _, _, _), do: {:error, "Unable to create token"}
end
