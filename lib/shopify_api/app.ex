defmodule ShopifyApi.App do
  defstruct name: "",
            client_id: "",
            client_secret: "",
            auth_redirect_uri: "",
            nonce: ""

  require Logger
  alias ShopifyApi.AuthRequest

  def install_url(%__MODULE__{} = app, domain) do
    query_params = [
      client_id: app.client_id,
      scope: app.scope,
      redirect_uri: app.auth_redirect_uri,
      state: app.nonce
    ]

    # "https://#{shop}.myshopify.com/admin/oauth/authorize?client_id=#{api_key}&scope=#{scopes}&redirect_uri=#{URI.encode(redirect_uri)}&state=#{nonce}"
    "https://#{domain}/admin/oauth/authorize?#{URI.encode_query(query_params)}"
  end

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
  @headers [{"Content-Type", "application/json"}]

  defp access_token_url(domain) do
    "https://#{domain}/admin/oauth/access_token"
  end

  def post(%ShopifyApi.App{} = app, domain, auth_code) do
    http_body = %{
      client_id: app.client_id,
      client_secret: app.client_secret,
      code: auth_code
    }

    HTTPoison.post(access_token_url(domain), Poison.encode!(http_body), @headers)
  end
end
