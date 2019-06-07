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
  alias ShopifyAPI.{AuthToken, CallLimit, Throttled}

  @default_api_version "2019-04"

  # Use HTTP in test for Bypass, HTTPS in all other environments
  @transport if Mix.env() == :test, do: "http://", else: "https://"

  @http_receive_timeout Application.get_env(:shopify_api, :http_timeout)

  ## Public Interface

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

  def version do
    Keyword.get(
      Application.get_env(:shopify_api, ShopifyAPI.REST) || [],
      :api_version,
      @default_api_version
    )
  end

  ## HTTPoison Overrides

  def request(%HTTPoison.Request{method: method, url: url} = request) do
    {time, response} = :timer.tc(&super/1, [request])
    log_request(method, url, time, response)

    response
  end

  def process_request_options(opts) do
    Keyword.put_new(opts, :recv_timeout, @http_receive_timeout)
  end

  def process_response_body(body) do
    Poison.decode(body)
  end

  ## Private Helpers

  defp shopify_request(method, url, body, headers, token) do
    response =
      Throttled.request(
        fn -> request(method, url, body, headers) end,
        token
      )

    case response do
      {:ok, %{status_code: status} = response} when status >= 200 and status < 300 ->
        # TODO probably have to return the response here if we want to use the headers
        {:ok, fetch_body(response)}

      {:ok, response} ->
        {:error, response}

      response ->
        {:error, response}
    end
  end

  defp log_request(method, url, time, response) do
    Logger.debug(fn ->
      module = __MODULE__ |> to_string() |> String.trim_leading("Elixir.")
      method = method |> to_string() |> String.upcase()

      "#{module} #{method} #{url} (#{call_limit(response)}) [#{div(time, 1_000)}ms]"
    end)
  end

  defp call_limit({:ok, response}) do
    response
    |> CallLimit.limit_header_or_status_code()
    |> CallLimit.get_api_call_limit()
  end

  defp call_limit(_), do: nil

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
end
