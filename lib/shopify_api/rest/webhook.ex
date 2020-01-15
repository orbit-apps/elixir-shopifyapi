defmodule ShopifyAPI.REST.Webhook do
  @moduledoc """
  """
  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST

  @doc """
  ## Helper method to generate the callback URI this server responds to.

  ## Example

  iex> ShopifyAPI.REST.Webhook.webhook_uri(%AuthToken{app_name: "some-shopify-app"})
  "https://shopifyapi-server.example.com/shop/webhook/some-shopify-app"
  """
  def webhook_uri(%AuthToken{app_name: app}) do
    # TODO this is brittle, we need to leverage URI and build correct paths here
    Application.get_env(:shopify_api, ShopifyAPI.Webhook)[:uri] <> "/#{app}"
  end

  @doc """
  ## Example

  iex> ShopifyAPI.REST.Webhook.all(auth)
  {:ok, %{"webhooks" => [%{"webhook_id" => "_", "address" => "https://example.com"}]}}
  """
  def all(%AuthToken{} = auth, params \\ []), do: REST.get(auth, "webhooks.json", params)

  def get(%AuthToken{} = auth, webhook_id, params \\ []),
    do: REST.get(auth, "webhooks/#{webhook_id}.json", params)

  def update(%AuthToken{} = auth, %{webhook: %{webhook_id: webhook_id}} = webhook),
    do: REST.put(auth, "webhooks/#{webhook_id}.json", webhook)

  @doc """
  ## Example

  iex> ShopifyAPI.REST.Webhook.delete(auth, webhook_id)
  {:ok, %{}}
  """
  def delete(%AuthToken{} = auth, webhook_id),
    do: REST.delete(auth, "webhooks/#{webhook_id}.json")

  @doc """
  ## Example

  iex> ShopifyAPI.REST.Webhook.create(auth, %{webhook: %{address: "https://example.com"}})
  {:ok, %{"webhook" => %{"webhook_id" => "_", "address" => "https://example.com"}}}
  """
  def create(%AuthToken{} = auth, %{webhook: %{}} = webhook),
    do: REST.post(auth, "webhooks.json", webhook)
end
