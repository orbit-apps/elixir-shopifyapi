defmodule ShopifyAPI.Bulk do
  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.Bulk.Query

  defmodule QueryError do
    defexception message: "Error in Bulk query"
  end

  @defaults [polling_rate: 100, max_poll_count: 100, auto_cancel: true]

  @doc """
  ## Options
    `:polling_rate` milliseconds between checks, defaults to 100
    `:max_poll_count` maximum times to check for bulk query completion, defaults to 100
    `:auto_cancel` `true` or `false` should try to cancel bulk query after
                   timeout, defaults to true

  ## Example
      iex> prod_id = 10
      iex> query = \"""
        {
          product(id: "gid://shopify/Product/\#{prod_id}") {
            collections(first: 1) {
              edges {
                node {
                  collection_id: id
                  }
                }
              }
            metafields(first: 1) {
              edges {
                node {
                  key
                  value
                  metafield_id: id
                }
              }
            }
          }
        }
      \"""
      iex> {:ok, token} = YourShopifyApp.ShopifyAPI.Shop.get_auth_token_from_slug("slug")
      iex> ShopifyAPI.Bulk.process!(token, query)
      [%{"collection_id" => "gid://shopify/Collection/xxx", ...}]
  """
  @spec process!(AuthToken.t(), String.t(), list() | integer()) :: list()
  def process!(token, query, polling_rate \\ 100)

  def process!(%AuthToken{} = token, query, polling_rate) when is_integer(polling_rate),
    do: process!(token, query, polling_rate: polling_rate)

  def process!(%AuthToken{} = token, query, opts) do
    token
    |> Query.exec(query, resolve_options(opts))
    |> Query.fetch()
    |> Query.parse_response!()
  end

  @doc """
  Like process/3 but returns a Streamable collection of decoded JSON or errors.

  ## Options
    `:polling_rate` milliseconds between checks, defaults to 100
    `:max_poll_count` maximum times to check for bulk query completion, defaults to 100
    `:auto_cancel` `true` or `false` should try to cancel bulk query after
                   timeout, defaults to true

    ## Example
      iex> prod_id = 10
      iex> query = \"""
        {
          product(id: "gid://shopify/Product/\#{prod_id}") {
            collections(first: 1) {
              edges {
                node {
                  collection_id: id
                  }
                }
              }
            metafields(first: 1) {
              edges {
                node {
                  key
                  value
                  metafield_id: id
                }
              }
            }
          }
        }
      \"""
      iex> {:ok, token} = YourShopifyApp.ShopifyAPI.Shop.get_auth_token_from_slug("slug")
      iex> ShopifyAPI.Bulk.process_stream(token, query)
           |> Enum.map(fn {:ok, json} -> IO.puts(json) end)
  """
  @spec process_stream(AuthToken.t(), String.t(), list() | integer()) :: Enumerable.t()
  def process_stream(token, query, polling_rate \\ 100)

  def process_stream(%AuthToken{} = token, query, polling_rate)
      when is_integer(polling_rate),
      do: process_stream(token, query, polling_rate: polling_rate)

  def process_stream(%AuthToken{} = token, query, opts) do
    with opts <- resolve_options(opts),
         {:ok, url} <- Query.exec(token, query, opts),
         {:ok, jsonl} <- Query.fetch(url) do
      jsonl
      |> String.splitter("\n", trim: true)
      |> Stream.map(&ShopifyAPI.JSONSerializer.decode/1)
    else
      {:error, _} = error ->
        [error]
    end
  end

  defp resolve_options(opts), do: Keyword.merge(@defaults, opts, fn _k, _dv, nv -> nv end)
end
