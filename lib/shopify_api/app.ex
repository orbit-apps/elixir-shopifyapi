defmodule ShopifyAPI.App do
  @moduledoc """
  ShopifyAPI.App contains logic and a struct for representing a Shopify App.
  """
  defstruct name: "",
            handle: "",
            client_id: "",
            client_secret: "",
            auth_redirect_uri: "",
            nonce: "",
            scope: "",
            config: %{}

  @typedoc """
  Type that represents a Shopify App
  """
  @type t :: %__MODULE__{
          name: String.t(),
          handle: String.t(),
          client_id: String.t(),
          client_secret: String.t(),
          auth_redirect_uri: String.t(),
          nonce: String.t(),
          scope: String.t(),
          # THE toml file
          config: map()
        }

  require Logger

  alias ShopifyAPI.AuthRequest
  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.JSONSerializer
  alias ShopifyAPI.UserToken

  @doc """
  Build a new App. Maybe even from a Toml file.

  Maybe even see:
  - https://hex.pm/packages/toml
  - https://shopify.dev/docs/apps/build/cli-for-apps/app-configuration
  """
  def new(
        %{
          "name" => name,
          "handle" => handle,
          "client_id" => client_id,
          "access_scopes" => %{"scopes" => scopes}
        } = toml_config
      ) do
    %__MODULE__{
      name: name,
      handle: handle,
      client_id: client_id,
      scope: scopes,
      config: toml_config
    }
  end

  @doc """
  The client secret likely lives in a runtime variable and should be loaded outside of the usual app definition.
  """
  def with_client_secret(%__MODULE__{} = app, client_secret),
    do: %{app | client_secret: client_secret}

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
