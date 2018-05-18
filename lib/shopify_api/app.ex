defmodule ShopifyApi.App do
  @moduledoc """
    ShopifyApi.App contains logic and a struct for representing a Shopify App.
  """
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
  alias ShopifyApi.AuthRequest

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

    # "https://#{shop}.myshopify.com/admin/oauth/authorize?client_id=#{api_key}&scope=#{scopes}&redirect_uri=#{URI.encode(redirect_uri)}&state=#{nonce}"
    "https://#{domain}/admin/oauth/authorize?#{URI.encode_query(query_params)}"
  end

  @doc """
    After an App is installed and the Shop owner ends up back on ourside of the fence we
    need to request an AuthToken. This function uses ShopifyApi.AuthRequest.post/3 to
    fetch and parse the AuthToken.
  """
  @spec fetch_token(__MODULE__.t(), String.t(), String.t()) :: {:ok, map()} | {:error, String.t()}
  def fetch_token(%__MODULE__{} = app, domain, auth_code) do
    # > body: "{\"access_token\":\"3e6ea1b6dc727cccc1ad50fff19e7908\",\"scope\":\"read_orders,write_products\"}",
    case AuthRequest.post(app, domain, auth_code) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        Logger.info("#{__MODULE__} [#{domain}] fetched token")
        # TODO probably don't use the ! ver of decode
        {:ok, body |> Poison.decode!() |> Map.get("access_token")}

      {:ok, %HTTPoison.Response{} = response} ->
        Logger.warn("#{__MODULE__} fetching token code: #{response.status_code}")
        {:error, response.status_code}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.warn("#{__MODULE__} error fetching token: #{inspect(reason)}")
        {:error, reason}
    end
  end
end

defmodule ShopifyApi.AuthRequest do
  @moduledoc """
    AuthRequest.post/3 contains logic to request AuthTokens from Shopify given an App,
    Shop domain, and the auth code from the App install.
  """
  require Logger
  @headers [{"Content-Type", "application/json"}]

  @transport "https://"
  if Mix.env() == :test do
    @transport "http://"
  end

  defp access_token_url(domain) do
    "#{@transport}#{domain}/admin/oauth/access_token"
  end

  @spec post(ShopifyApi.App.t(), String.t(), String.t()) :: {:ok, any()} | {:error, any()}
  def post(%ShopifyApi.App{} = app, domain, auth_code) do
    http_body = %{
      client_id: app.client_id,
      client_secret: app.client_secret,
      code: auth_code
    }

    Logger.debug("#{__MODULE__} requesting token from #{access_token_url(domain)}")
    HTTPoison.post(access_token_url(domain), Poison.encode!(http_body), @headers)
  end
end
