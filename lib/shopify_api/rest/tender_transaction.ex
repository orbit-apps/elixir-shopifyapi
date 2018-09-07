defmodule ShopifyAPI.REST.TenderTransaction do
  @moduledoc """
  """
  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST.Request

  @doc """
    Return all the Tender Transactions.
  """
  def all(%AuthToken{} = auth),
    do: Request.get(auth, "tender_transactions.json")
end
