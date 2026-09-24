defmodule ShopifyAPI.Bulk do
  @moduledoc """
  Runs Shopify bulk query operations and returns their results.

  A bulk operation is identified by a shop's myshopify domain and an app name, not by a token.
  Before every request, the token cached for that pair is looked up with
  `ShopifyAPI.AuthToken.fetch/2`, so an operation that runs longer than a token's lifetime keeps
  working across refreshes. Raises `ShopifyAPI.ShopAuthError` when no usable token is cached —
  `fetch/2` returns `{:error, :not_found}` or `{:error, :needs_reacquisition}`.

  Each function also accepts an `ShopifyAPI.AuthToken` in place of the domain and app name. Only
  its `shop_name` and `app_name` are used; the token itself is looked up from the cache as above.
  """

  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.Bulk.Query

  defmodule QueryError do
    defexception message: "Error in Bulk query"
  end

  defmodule TimeoutError do
    defexception message: "Bulk operation timed out"
  end

  defmodule InProgressError do
    defexception message: "Bulk operation already in progress"
  end

  @defaults [polling_rate: 100, max_poll_count: 100, auto_cancel: true]

  @doc """
  Like `process!/4`, identifying the shop and app by a token's `shop_name` and `app_name`.
  """
  @spec process!(AuthToken.t(), String.t()) :: list()
  def process!(%AuthToken{} = token, query), do: process!(token, query, [])

  @doc """
  Like `process!/4`, with either default options or the shop and app taken from a token.

  Called as `process!(myshopify_domain, app_name, query)`, it uses the default options. Called as
  `process!(token, query, opts)`, it identifies the shop and app by the token's `shop_name` and
  `app_name`.
  """
  @spec process!(String.t(), String.t(), String.t()) :: list()
  @spec process!(AuthToken.t(), String.t(), Keyword.t() | integer()) :: list()
  def process!(%AuthToken{} = token, query, opts),
    do: process!(token.shop_name, token.app_name, query, opts)

  def process!(myshopify_domain, app_name, query) when is_binary(myshopify_domain),
    do: process!(myshopify_domain, app_name, query, [])

  @doc """
  Runs a bulk query, waits for it to complete, and returns the decoded results.

  An integer in place of `opts` is taken as the `:polling_rate`.

  ## Options
    - `:polling_rate` milliseconds between checks, defaults to 100
    - `:max_poll_count` maximum times to check for bulk query completion, defaults to 100
    - `:auto_cancel` boolean, should try to cancel bulk query after
                   timeout, defaults to true
    - `:group_objects` boolean, WARNING only available in GraphQL API version 2026-01 and above
                   Should Objects be grouped in the response, according to Shopify grouping can
                   slow down the query.

  ## Example
      iex> query = \"""
        {
          product(id: "gid://shopify/Product/10") {
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
      iex> ShopifyAPI.Bulk.process!("shop.myshopify.com", "my-app", query)
      [%{"collection_id" => "gid://shopify/Collection/xxx", ...}]
  """
  @spec process!(String.t(), String.t(), String.t(), Keyword.t() | integer()) :: list()
  def process!(myshopify_domain, app_name, query, polling_rate) when is_integer(polling_rate),
    do: process!(myshopify_domain, app_name, query, polling_rate: polling_rate)

  def process!(myshopify_domain, app_name, query, opts)
      when is_binary(myshopify_domain) and is_binary(app_name) do
    token = Query.current_token!(myshopify_domain, app_name)

    token
    |> Query.exec!(query, resolve_options(opts))
    |> Query.fetch(token)
    |> Query.parse_response!()
  end

  @doc """
  Like `process_stream!/4`, identifying the shop and app by a token's `shop_name` and
  `app_name`.
  """
  @spec process_stream!(AuthToken.t(), String.t()) :: Enumerable.t()
  def process_stream!(%AuthToken{} = token, query), do: process_stream!(token, query, [])

  @doc """
  Like `process_stream!/4`, with either default options or the shop and app taken from a token.

  Called as `process_stream!(myshopify_domain, app_name, query)`, it uses the default options.
  Called as `process_stream!(token, query, opts)`, it identifies the shop and app by the token's
  `shop_name` and `app_name`.
  """
  @spec process_stream!(String.t(), String.t(), String.t()) :: Enumerable.t()
  @spec process_stream!(AuthToken.t(), String.t(), Keyword.t() | integer()) :: Enumerable.t()
  def process_stream!(%AuthToken{} = token, query, opts),
    do: process_stream!(token.shop_name, token.app_name, query, opts)

  def process_stream!(myshopify_domain, app_name, query) when is_binary(myshopify_domain),
    do: process_stream!(myshopify_domain, app_name, query, [])

  @doc """
  Like `process!/4` but returns a Streamable collection of decoded JSON.

  Takes the same options as `process!/4`.

  ## Example
      iex> query = \"""
        {
          products {
            edges {
              node {
                id
              }
            }
          }
        }
      \"""
      iex> "shop.myshopify.com" |> ShopifyAPI.Bulk.process_stream!("my-app", query) |> Enum.to_list()
      [
        %{"id" => "gid://shopify/Product/1"},
        %{"id" => "gid://shopify/Product/2"},
        %{"id" => "gid://shopify/Product/3"}
      ]
  """
  @spec process_stream!(String.t(), String.t(), String.t(), Keyword.t() | integer()) ::
          Enumerable.t()
  def process_stream!(myshopify_domain, app_name, query, polling_rate)
      when is_integer(polling_rate),
      do: process_stream!(myshopify_domain, app_name, query, polling_rate: polling_rate)

  def process_stream!(myshopify_domain, app_name, query, opts)
      when is_binary(myshopify_domain) and is_binary(app_name) do
    token = Query.current_token!(myshopify_domain, app_name)

    token
    |> Query.exec!(query, resolve_options(opts))
    |> Query.stream_fetch!(token)
    |> decode_json!()
  end

  @doc """
  Like `process_stream_from_id!/3`, identifying the shop and app by a token's `shop_name` and
  `app_name`.
  """
  @spec process_stream_from_id!(AuthToken.t(), String.t()) :: Enumerable.t()
  def process_stream_from_id!(%AuthToken{} = token, bulk_op_id),
    do: process_stream_from_id!(token.shop_name, token.app_name, bulk_op_id)

  @doc """
  Streams the decoded results of an already completed bulk operation, given its ID.

  Does not poll: the operation must have finished.
  """
  @spec process_stream_from_id!(String.t(), String.t(), String.t()) :: Enumerable.t()
  def process_stream_from_id!(myshopify_domain, app_name, bulk_op_id) do
    token = Query.current_token!(myshopify_domain, app_name)

    token
    |> Query.fetch_url!(bulk_op_id)
    |> Query.stream_fetch!(token)
    |> decode_json!()
  end

  defp resolve_options(opts), do: Keyword.merge(@defaults, opts, fn _k, _dv, nv -> nv end)

  defp decode_json!(stream), do: Stream.map(stream, &ShopifyAPI.JSONSerializer.decode!/1)
end
