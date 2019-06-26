defmodule ShopifyAPI.REST.AccessScope do
  @moduledoc """
  Shopify REST API Access Scope resources.
  """

  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST

  @doc """
  Return a list of all access scopes associated with the access token.

  ## Example

      iex> ShopifyAPI.REST.AccessScope.get(auth)
      {:ok, %{ "access_scopes" => [] }}
  """
  def get(%AuthToken{} = auth), do: REST.get(auth, "oauth/access_scopes.json")
end
