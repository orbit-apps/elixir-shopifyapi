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
  Options:
    * `:pagination` - Can be `:none`, `:stream`, or `:auto`. Defaults to :auto
      `:none` will only return the first page. You won't have access to the headers to manually
      paginate.
      `:auto` will block until all the pages have been retrieved and concatenated together.
      `:stream` will return a `Stream`, prepopulated with the first page.
  """
  @spec get(AuthToken.t(), path :: String.t(), keyword(), keyword()) ::
          {:ok, %{required(String.t()) => [map()]}} | Enumerable.t()
  def get(%AuthToken{} = auth, path, params \\ [], options \\ []) do
    collect_results = fn
      %{} = result, {:ok, acc} -> {:cont, {:ok, [result | acc]}}
      error, {:ok, _acc} -> {:halt, error}
    end

    case pagination(options) do
      :none ->
        with {:ok, response} <- Request.perform(auth, :get, path, "", params) do
          {:ok, fetch_body(response)}
        end

      :stream ->
        Request.stream(auth, path, params)

      _auto_or_nil ->
        Request.stream(auth, path, params)
        |> Enum.reduce_while({:ok, []}, collect_results)
        |> case do
          {:ok, results} -> {:ok, Enum.reverse(results)}
          error -> error
        end
    end
  end

  @doc false
  def post(%AuthToken{} = auth, path, object \\ %{}) do
    with {:ok, body} <- JSONSerializer.encode(object) do
      perform_request(auth, :post, path, body)
    end
  end

  @doc false
  def put(%AuthToken{} = auth, path, object) do
    with {:ok, body} <- JSONSerializer.encode(object) do
      perform_request(auth, :put, path, body)
    end
  end

  @doc false
  def delete(%AuthToken{} = auth, path), do: perform_request(auth, :delete, path)

  defp perform_request(auth, method, path, body \\ "") do
    with {:ok, response} <- Request.perform(auth, method, path, body),
         response_body <- fetch_body(response) do
      {:ok, response_body}
    end
  end

  defp fetch_body(http_response) do
    with {:ok, map_fetched} <- Map.fetch(http_response, :body),
         {:ok, body} <- map_fetched,
         do: body
  end

  @spec pagination(keyword) :: atom | nil
  defp pagination(options) do
    Keyword.get(options, :pagination, Application.get_env(:shopify_api, :pagination, :auto))
  end
end
