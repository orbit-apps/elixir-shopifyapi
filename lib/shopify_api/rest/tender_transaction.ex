defmodule ShopifyAPI.REST.TenderTransaction do
  @moduledoc """
  """
  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST

  @shopify_per_page_max 250

  @doc """
    Return all the Tender Transactions.
  """
  def all(%AuthToken{} = auth, params \\ [], options \\ []),
    do: REST.get(auth, "tender_transactions.json", params, options)

  def max_per_page, do: @shopify_per_page_max
end
