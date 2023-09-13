defmodule ShopifyAPI.App do
  @moduledoc """
  ShopifyAPI.App contains logic and a struct for representing a Shopify App.
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

  @per_user_query_params ["grant_options[]": "per-user"]

  require Logger

  alias ShopifyAPI.AssociatedUser
  alias ShopifyAPI.AuthRequest
  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.JSONSerializer
  alias ShopifyAPI.UserToken

  @doc """
  Generates the install URL for an App and a Shop.
  """
  @spec install_url(__MODULE__.t(), String.t(), boolean()) :: String.t()
  def install_url(app, domain, per_user \\ false)
      when is_struct(app, __MODULE__) and is_binary(domain) do
    query_params = app |> install_query_params(per_user) |> URI.encode_query()

    %URI{scheme: "https", port: 443, host: domain, path: "/admin/oauth/authorize"}
    |> URI.append_query(query_params)
    |> URI.to_string()
  end

  @doc """
  After an App is installed and the Shop owner ends up back on ourside of the fence we
  need to request an AuthToken. This function uses ShopifyAPI.AuthRequest.post/3 to
  fetch and parse the AuthToken.
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

  defp install_query_params(app, per_user) do
    [
      client_id: app.client_id,
      scope: app.scope,
      redirect_uri: app.auth_redirect_uri,
      state: app.nonce
    ] ++ per_user_query_params(per_user)
  end

  defp per_user_query_params(true), do: @per_user_query_params
  defp per_user_query_params(_per_user_enabled), do: []

  defp create_token(
         %{"associated_user" => associated_user, "access_token" => token},
         app,
         domain,
         auth_code
       ) do
    Logger.debug("online token")
    user = AssociatedUser.from_auth_request(associated_user)
    {:ok, UserToken.new(app, domain, user, auth_code, token)}
  end

  defp create_token(%{"access_token" => token}, app, domain, auth_code) do
    Logger.debug("offline token")
    {:ok, AuthToken.new(app, domain, auth_code, token)}
  end

  defp create_token(_, _, _, _), do: {:error, "Unable to create token"}
end
