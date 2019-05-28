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
  require Logger

  alias HTTPoison.{AsyncResponse, Error, Response}
  alias ShopifyAPI.{AuthToken, CallLimit, Throttled, ThrottleServer}

  @default_api_version "2019-04"

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
        {time, response} =
          :timer.tc(fn ->
            request(action, url, body, headers, recv_timeout: @http_receive_timeout)
          end)

        log_request(action, url, time, response)

        case response do
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

  defp log_request(action, url, time, response) do
    Logger.debug(fn ->
      module = __MODULE__ |> to_string() |> String.trim_leading("Elixir.")
      action = action |> to_string() |> String.upcase()

      call_limit =
        case response do
          {:ok, http_response} -> CallLimit.limit_header_or_status_code(http_response)
          _ -> nil
        end

      "#{module} #{action} #{url} (#{call_limit}) [#{div(time, 1_000)}ms]"
    end)
  end

  def process_response_body(body), do: Poison.decode(body)

  defp url(%{shop_name: domain}, path),
    do: "#{@transport}#{domain}/admin/api/#{version()}/#{path}"

  defp headers(%{token: access_token}) do
    [
      {"Content-Type", "application/json"},
      {"X-Shopify-Access-Token", access_token}
    ]
  end

  defp fetch_body(http_response) do
    with {:ok, map_fetched} <- Map.fetch(http_response, :body),
         {:ok, body} <- map_fetched,
         do: body
  end

  def version do
    Keyword.get(
      Application.get_env(:shopify_api, ShopifyAPI.REST) || [],
      :api_version,
      @default_api_version
    )
  end
end
