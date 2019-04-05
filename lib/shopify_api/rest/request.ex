defmodule ShopifyAPI.REST.Request do
  @moduledoc """
  Provides basic REST actions for hitting the Shopify API. Don't use this
  directly instead use one of the helper modules such as `ShopifyAPI.REST.Product`.

  Actons provided, the names correspond to the HTTP Action called.
    - get
    - put
    - post
    - delete
  """

  use HTTPoison.Base

  alias HTTPoison.{AsyncResponse, Error, Response}
  alias ShopifyAPI.{AuthToken, Throttled, ThrottleServer}

  @transport "https://"
  if Mix.env() == :test do
    @transport "http://"
  end

  @http_receive_timeout Application.get_env(:shopify_api, :http_timeout)

  @spec get(AuthToken.t(), String.t()) ::
          {:ok, Response.t() | AsyncResponse.t()} | {:error, Error.t()}
  def get(auth, path), do: shopify_request(:get, url(auth, path), "", headers(auth), auth)

  @spec put(AuthToken.t(), String.t(), map()) ::
          {:ok, Response.t() | AsyncResponse.t()} | {:error, Error.t()}
  def put(auth, path, object),
    do: shopify_request(:put, url(auth, path), Poison.encode!(object), headers(auth), auth)

  @spec post(AuthToken.t(), String.t(), map()) ::
          {:ok, Response.t() | AsyncResponse.t()} | {:error, Error.t()}
  def post(auth, path, object \\ %{}),
    do: shopify_request(:post, url(auth, path), Poison.encode!(object), headers(auth), auth)

  @spec delete(AuthToken.t(), String.t()) ::
          {:ok, Response.t() | AsyncResponse.t()} | {:error, Error.t()}
  def delete(auth, path), do: shopify_request(:delete, url(auth, path), "", headers(auth), auth)

  defp shopify_request(action, url, body, headers, token) do
    Throttled.request(
      fn ->
        case request(action, url, body, headers, recv_timeout: @http_receive_timeout) do
          {:ok, %{status_code: status} = response} when status >= 200 and status < 300 ->
            # TODO probably have to return the response here if we want to use the headers
            ThrottleServer.update_api_call_limit(response, token)
            {:ok, fetch_body(response)}

          {:ok, response} ->
            ThrottleServer.update_api_call_limit(response, token)
            {:error, response}

          response ->
            {:error, response}
        end
      end,
      token
    )
  end

  defp url(%{shop_name: domain}, path) do
    "#{@transport}#{domain}/admin/#{path}"
  end

  defp headers(%{token: access_token}) do
    [
      {"Content-Type", "application/json"},
      {"X-Shopify-Access-Token", access_token}
    ]
  end

  defp fetch_body(http_response) do
    with {:ok, map_fetched} <- http_response |> Map.fetch(:body),
         {:ok, body} <- map_fetched,
         do: body
  end

  def process_response_body(body) do
    body |> Poison.decode()
  end
end
