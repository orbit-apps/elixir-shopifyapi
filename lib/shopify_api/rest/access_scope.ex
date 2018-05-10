defmodule ShopifyApi.Rest.AccessScope do
  @moduledoc """
  Shopify REST API Access Scope resources.
  """

  alias ShopifyApi.AuthToken
  alias ShopifyApi.Rest.Request

  @doc """
  Return a list of all access scopes associated with the access token.

  ## Example

      iex> ShopifyApi.Rest.AccessScope.get(auth)
      {:ok, %{ "access_scopes" => [] }}
  """
  def get(%AuthToken{} = auth) do
    Request.get(auth, "oauth/access_scopes.json")
  end
end
