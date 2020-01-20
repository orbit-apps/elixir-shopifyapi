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
  def get(%AuthToken{} = auth, path, params \\ [], options \\ []) do
    case pagination(options) do
      :none ->
        with {:ok, response} <- Request.perform(auth, :get, path, "", params) do
          {:ok, fetch_body(response)}
        end

      :stream ->
        Request.stream(auth, path, params)

      _auto_or_nil ->
        auth
        |> Request.stream(path, params)
        |> Enum.to_list()
    end
  end

  @doc false
  def post(%AuthToken{} = auth, path, object \\ %{}) do
    with {:ok, body} <- JSONSerializer.encode(object),
         {:ok, response} <- Request.perform(auth, :post, path, body),
         response_body <- fetch_body(response) do
      {:ok, response_body}
    end
  end

  @doc false
  def put(%AuthToken{} = auth, path, object) do
    with {:ok, body} <- JSONSerializer.encode(object),
         {:ok, response} <- Request.perform(auth, :put, path, body),
         response_body <- fetch_body(response) do
      {:ok, response_body}
    end
  end

  @doc false
  def delete(%AuthToken{} = auth, path) do
    with {:ok, response} <- Request.perform(auth, :delete, path),
         response_body <- fetch_body(response) do
      {:ok, response_body}
    end
  end

  def fetch_body(http_response) do
    with {:ok, map_fetched} <- Map.fetch(http_response, :body),
         {:ok, body} <- map_fetched,
         do: body
  end

  @spec pagination(keyword) :: atom | nil
  defp pagination(options) do
    Keyword.get(options, :pagination, Application.get_env(:shopify_api, :pagination, :none))
  end
end
