defmodule ShopifyAPI.REST.Request do
  @moduledoc """
  The internal interface to Shopify's REST Admin API, built on HTTPoison.

  Adds support for building URLs and authentication headers from an AuthToken,
  as well as functionality to throttle/log requests and parse responses.
  """

  use HTTPoison.Base
  require Logger

  alias HTTPoison.Error
  alias ShopifyAPI.{AuthToken, CallLimit, JSONSerializer, Throttled}

  @default_api_version "2020-01"

  # Use HTTP in test for Bypass, HTTPS in all other environments
  @transport if Mix.env() == :test, do: "http://", else: "https://"

  @http_receive_timeout Application.get_env(:shopify_api, :http_timeout)

  @type http_method :: :get | :post | :put | :delete

  ## Public Interface

  @spec perform(
          AuthToken.t(),
          http_method(),
          path :: String.t(),
          body :: String.t(),
          params :: keyword()
        ) :: {:ok, HTTPoison.Response.t()} | {:error, HTTPoison.Response.t() | any()}
  def perform(%AuthToken{} = token, method, path, body \\ "", params \\ []) do
    url = token |> url(path) |> add_params_to_url(params)
    headers = headers(token)

    transform_response(
      Throttled.request(
        fn -> logged_request(method, url, body, headers, token: token) end,
        token
      )
    )
  end

  @spec transform_response(HTTPoison.Response.t()) :: {:error, any()} | {:ok, any()}
  def transform_response(response) do
    case response do
      {:ok, %{status_code: status} = response} when status >= 200 and status < 300 ->
        {:ok, response}

      {:ok, response} ->
        {:error, response}

      {:error, _} = value ->
        value

      response ->
        {:error, response}
    end
  end

  @spec stream(AuthToken.t(), String.t(), keyword()) :: Enumerable.t() | no_return()
  def stream(auth, path, params) do
    headers = headers(auth)

    Stream.resource(
      fn -> auth |> url(path) |> add_params_to_url(params) end,
      fn url ->
        shopify_response =
          Throttled.request(fn -> logged_request(:get, url, "", headers, token: auth) end, auth)

        case transform_response(shopify_response) do
          {:ok, resp} ->
            results = extract_results!(resp)

            # TODO(BJ) - Credo complaining about nesting depth
            case extract_next_link(resp.headers) do
              nil -> {:halt, results}
              next_url -> {results, next_url}
            end

          value ->
            {:halt, value}
        end
      end,
      fn _ -> :ok end
    )
  end

  def version do
    Keyword.get(
      Application.get_env(:shopify_api, ShopifyAPI.REST) || [],
      :api_version,
      @default_api_version
    )
  end

  ## HTTPoison Overrides

  def logged_request(method, url, body, headers, options) do
    {time, response} = :timer.tc(&request/5, [method, url, body, headers, options])
    token = Keyword.get(options, :token, %ShopifyAPI.AuthToken{})

    log_request(token, method, url, time, response)
    send_telemetry(token, method, url, time, response)

    response
  end

  @impl true
  def process_request_options(opts) do
    Keyword.put_new(opts, :recv_timeout, @http_receive_timeout)
  end

  @impl true
  def process_response_body(body) do
    with {:ok, results_map} <- JSONSerializer.decode(body),
         [{_key, results}] <- Map.to_list(results_map) do
      results
    end
  end

  ## Private Helpers

  defp send_telemetry(
         %{app_name: app, shop_name: shop} = _token,
         method,
         url,
         time,
         {:ok, %{status_code: status}} = response
       ) do
    :telemetry.execute(
      [:shopify_api, :rest_request, :success],
      %{request_time: time, remaining_calls: remaining_calls(response)},
      %{
        app: app,
        shop: shop,
        url: url,
        status_code: status,
        method: method,
        module: module_name()
      }
    )
  end

  defp send_telemetry(
         %{app_name: app, shop_name: shop} = _token,
         method,
         url,
         time,
         {:error, %Error{reason: reason}} = _response
       ) do
    :telemetry.execute(
      [:shopify_api, :rest_request, :failure],
      %{request_time: time},
      %{
        app: app,
        shop: shop,
        url: url,
        method: method,
        module: module_name(),
        reason: reason
      }
    )
  end

  defp send_telemetry(_token, _method, _url, _time, _response), do: nil

  defp log_request(token, method, url, time, response) do
    Logger.debug(fn ->
      %{app_name: app, shop_name: shop} = token
      module = module_name()
      method = method |> to_string() |> String.upcase()

      "#{module} #{method} #{url} #{app} #{shop} (#{remaining_calls(response)}) [#{
        div(time, 1_000)
      }ms]"
    end)
  end

  defp module_name do
    __MODULE__ |> to_string() |> String.trim_leading("Elixir.")
  end

  defp remaining_calls({:ok, response}) do
    response
    |> CallLimit.limit_header_or_status_code()
    |> CallLimit.get_api_remaining_calls()
  end

  defp remaining_calls(_), do: nil

  defp url(%{shop_name: domain}, path),
    do: "#{@transport}#{domain}/admin/api/#{version()}/#{path}"

  defp headers(%{token: access_token}) do
    [
      {"Content-Type", "application/json"},
      {"X-Shopify-Access-Token", access_token}
    ]
  end

  @spec add_params_to_url(binary, list | map) :: binary
  defp add_params_to_url(url, params) when is_map(params) do
    list_params = Enum.map(params, fn {key, value} -> {String.to_existing_atom(key), value} end)
    add_params_to_url(url, list_params)
  end

  defp add_params_to_url(url, params) do
    url
    |> URI.parse()
    |> merge_uri_params(params)
    |> to_string()
  end

  @spec merge_uri_params(URI.t(), list) :: URI.t()
  defp merge_uri_params(uri, []), do: uri

  defp merge_uri_params(%URI{query: nil} = uri, params) when is_list(params) or is_map(params) do
    Map.put(uri, :query, URI.encode_query(params))
  end

  defp merge_uri_params(%URI{} = uri, params) when is_list(params) or is_map(params) do
    Map.update!(uri, :query, fn q ->
      q
      |> URI.decode_query()
      |> Map.merge(param_list_to_map_with_string_keys(params))
      |> URI.encode_query()
    end)
  end

  @spec param_list_to_map_with_string_keys(list) :: map
  defp param_list_to_map_with_string_keys(list) when is_list(list) or is_map(list) do
    for {key, value} <- list, into: Map.new() do
      {"#{key}", value}
    end
  end

  @spec extract_results!(HTTPoison.Response.t()) :: list() | no_return()
  defp extract_results!(%HTTPoison.Response{body: body}) do
    with {:ok, results_map} <- body,
         [{_key, results}] <- Map.to_list(results_map) do
      results
    end
  end

  @link_regex ~r/<(?<link>.*)>;\s*rel=\"(?<rel>.*)\"/

  @spec extract_next_link(list) :: binary | nil
  defp extract_next_link(headers) do
    for {"Link", link_header} <- headers,
        links <- String.split(link_header, ",") do
      case Regex.named_captures(@link_regex, links) do
        %{"link" => link, "rel" => "next"} -> link
        _ -> nil
      end
    end
    |> Enum.filter(&(not is_nil(&1)))
    |> List.first()
  end
end
