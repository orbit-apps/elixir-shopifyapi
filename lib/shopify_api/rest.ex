defmodule ShopifyAPI.REST do
  @moduledoc """
  Provides core REST actions for interacting with the Shopify API.
  Uses an `AuthToken` for authorization and request rate limiting.

  Please don't use this module directly. Instead prefer the higher-level modules
  implementing appropriate resource endpoints, such as `ShopifyAPI.REST.Product`
  """

  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.JSONSerializer
  alias ShopifyAPI.REST.Request

  @doc """
  Underlying utility retrieval function. The options passed affect both the
  return value and, ultimately, the number of requests made to Shopify.

  ## Options

    `:pagination` - Can be `:none`, `:stream`, or `:auto`. Defaults to :auto
    `:auto` will block until all the pages have been retrieved and concatenated together.
    `:none` will only return the first page. You won't have access to the headers to manually
      paginate.
    `:stream` will return a `Stream`, prepopulated with the first page.
  """
  @spec get(AuthToken.t(), path :: String.t(), keyword(), keyword()) ::
          {:ok, %{required(String.t()) => [map()]}} | Enumerable.t()
  def get(%AuthToken{} = auth, path, params \\ [], options \\ []) do
    case pagination(options) do
      :none ->
        with {:ok, response} <- Request.perform(auth, :get, path, "", params) do
          {:ok, fetch_body(response)}
        end

      :stream ->
        Request.stream(auth, path, params)

      :auto ->
        auth
        |> Request.stream(path, params)
        |> collect_results()
    end
  end

  @spec collect_results(Enumerable.t()) ::
          {:ok, list()} | {:error, HTTPoison.Response.t() | any()}
  defp collect_results(stream) do
    stream
    |> Enum.reduce_while({:ok, []}, fn
      {:error, _} = error, {:ok, _acc} -> {:halt, error}
      result, {:ok, acc} -> {:cont, {:ok, [result | acc]}}
    end)
    |> case do
      {:ok, results} -> {:ok, Enum.reverse(results)}
      error -> error
    end
  end

  @doc false
  def post(%AuthToken{} = auth, path, object \\ %{}, options \\ []) do
    with {:ok, body} <- JSONSerializer.encode(object) do
      perform_request(auth, :post, path, body, options)
    end
  end

  @doc false
  def put(%AuthToken{} = auth, path, object, options \\ []) do
    with {:ok, body} <- JSONSerializer.encode(object) do
      perform_request(auth, :put, path, body, options)
    end
  end

  @doc false
  def delete(%AuthToken{} = auth, path), do: perform_request(auth, :delete, path)

  defp perform_request(auth, method, path, body \\ "", options \\ []) do
    with {:ok, response} <- Request.perform(auth, method, path, body, [], options),
         response_body <- fetch_body(response) do
      {:ok, response_body}
    end
  end

  defp fetch_body(http_response) do
    Map.fetch!(http_response, :body)
  end

  @spec pagination(keyword) :: atom | nil
  defp pagination(options) do
    Keyword.get(options, :pagination, Application.get_env(:shopify_api, :pagination, :auto))
  end
end
