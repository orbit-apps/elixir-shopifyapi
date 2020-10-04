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

  require Logger
  alias ShopifyAPI.AuthRequest
  alias ShopifyAPI.JSONSerializer

  @doc """
    Generates the install URL for an App and a Shop.
  """
  @spec install_url(__MODULE__.t(), String.t()) :: String.t()
  def install_url(%__MODULE__{} = app, domain) when is_binary(domain) do
    query_params = [
      client_id: app.client_id,
      scope: app.scope,
      redirect_uri: app.auth_redirect_uri,
      state: app.nonce
    ]

    "https://#{domain}/admin/oauth/authorize?#{URI.encode_query(query_params)}"
  end

  @doc """
    After an App is installed and the Shop owner ends up back on ourside of the fence we
    need to request an AuthToken. This function uses ShopifyAPI.AuthRequest.post/3 to
    fetch and parse the AuthToken.
  """
  @spec fetch_token(__MODULE__.t(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, String.t()}
  def fetch_token(%__MODULE__{} = app, domain, auth_code) do
    case AuthRequest.post(app, domain, auth_code) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        Logger.info(fn -> "#{__MODULE__} [#{domain}] fetched token" end)
        # TODO probably don't use the ! ver of decode
        {:ok, body |> JSONSerializer.decode!() |> Map.get("access_token")}

      {:ok, %HTTPoison.Response{} = response} ->
        Logger.warn(fn -> "#{__MODULE__} fetching token code: #{response.status_code}" end)
        {:error, response.status_code}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.warn(fn -> "#{__MODULE__} error fetching token: #{inspect(reason)}" end)
        {:error, reason}
    end
  end
end

defmodule ShopifyAPI.AuthRequest do
  @moduledoc """
    AuthRequest.post/3 contains logic to request AuthTokens from Shopify given an App,
    Shop domain, and the auth code from the App install.
  """
  require Logger

  alias ShopifyAPI.JSONSerializer
  @headers [{"Content-Type", "application/json"}]

  defp access_token_url(domain) do
    d = if ShopifyAPI.bypass_host(), do: ShopifyAPI.bypass_host(), else: domain
    "#{ShopifyAPI.transport()}#{d}/admin/oauth/access_token"
  end

  @spec post(ShopifyAPI.App.t(), String.t(), String.t()) :: {:ok, any()} | {:error, any()}
  def post(%ShopifyAPI.App{} = app, domain, auth_code) do
    http_body = %{
      client_id: app.client_id,
      client_secret: app.client_secret,
      code: auth_code
    }

    Logger.debug(fn -> "#{__MODULE__} requesting token from #{access_token_url(domain)}" end)
    encoded_body = JSONSerializer.encode!(http_body)
    HTTPoison.post(access_token_url(domain), encoded_body, @headers)
  end
end
