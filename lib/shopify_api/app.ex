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
  alias ShopifyAPI.{Config, JSONSerializer, ShopifyAuthRequest}

  def auth_install_uri(app) do
    case Config.lookup(__MODULE__, :install_uri) do
      {module, function, args} -> apply(module, function, args ++ [app: app])
      {module, function} -> apply(module, function, app: app)
      nil -> {:error, "no ShopifyAPI.App install_uri configured"}
    end
  end

  def auth_redirect_uri(app) do
    case Config.lookup(__MODULE__, :run_url) do
      {module, function, args} -> apply(module, function, args ++ [app: app])
      {module, function} -> apply(module, function, app: app)
      nil -> {:error, "no ShopifyAPI.App run_url configured"}
    end
  end

  @doc """
    After an App is installed and the Shop owner ends up back on ourside of the fence we
    need to request an AuthToken. This function uses ShopifyAPI.ShopifyAuthRequest.post/3 to
    fetch and parse the AuthToken.
  """
  @spec fetch_token(__MODULE__.t(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, String.t()}
  def fetch_token(%__MODULE__{} = app, domain, auth_code) do
    case ShopifyAuthRequest.post(app, domain, auth_code) do
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
