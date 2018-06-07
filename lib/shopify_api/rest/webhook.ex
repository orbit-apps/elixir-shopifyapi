defmodule ShopifyAPI.REST.Webhook do
  @moduledoc """
  """
  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST.{Request, Webhook}

  @doc """
  ## Helper method to generate the callback URI this server responds to.

  ## Example

  iex> ShopifyAPI.REST.Webhook.webhook_uri(%AuthToken{app_name: "some-shopify-app"})
  "https://shopifyapi-server.example.com/shop/webhook/some-shopify-app"
  """
  def webhook_uri(%AuthToken{app_name: app}) do
    # TODO this is brittle, we need to leverage URI and build correct paths here
    Application.get_env(:shopify_api, Webhook)[:uki] <> "/#{app}"
  end

  @doc """
  ## Example

  iex> ShopifyAPI.REST.Webhook.all(auth)
  {:ok, %{"webhooks" => [%{"webhook_id" => "_", "address" => "https://example.com"}]}}
  """
  def all(%AuthToken{} = auth) do
    Request.get(auth, "webhooks.json")
  end

  def get(%AuthToken{} = auth, webhook_id) do
    Request.get(auth, "webhooks/#{webhook_id}.json")
  end

  def update(%AuthToken{} = auth, %{webhook: %{webhook_id: webhook_id}} = webhook) do
    Request.put(auth, "webhooks/#{webhook_id}.json", webhook)
  end

  @doc """
  ## Example

  iex> ShopifyAPI.REST.Webhook.delete(auth, webhook_id)
  {:ok, %{}}
  """
  def delete(%AuthToken{} = auth, webhook_id) do
    Request.delete(auth, "webhooks/#{webhook_id}.json")
  end

  @doc """
  ## Example

  iex> ShopifyAPI.REST.Webhook.create(auth, %{webhook: %{address: "https://example.com"}})
  {:ok, %{"webhook" => %{"webhook_id" => "_", "address" => "https://example.com"}}}
  """
  def create(%AuthToken{} = auth, %{webhook: %{}} = webhook) do
    Request.post(auth, "webhooks.json", webhook)
  end
end
