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

  @doc false
  def get(%AuthToken{} = auth, path, params \\ []) do
    Request.perform(auth, :get, path, "", params)
  end

  @doc false
  def post(%AuthToken{} = auth, path, object \\ %{}) do
    with {:ok, body} <- JSONSerializer.encode(object),
         do: Request.perform(auth, :post, path, body)
  end

  @doc false
  def put(%AuthToken{} = auth, path, object) do
    with {:ok, body} <- JSONSerializer.encode(object),
         do: Request.perform(auth, :put, path, body)
  end

  @doc false
  def delete(%AuthToken{} = auth, path) do
    Request.perform(auth, :delete, path)
  end
end
