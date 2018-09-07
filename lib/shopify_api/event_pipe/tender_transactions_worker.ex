defmodule ShopifyAPI.EventPipe.TenderTransactionWorker do
  @moduledoc """
  Worker for processing Tender Transactions
  """
  import ShopifyAPI.EventPipe.Worker
  alias ShopifyAPI.REST.TenderTransaction

  def perform(%{action: "all", token: _} = event) do
    execute_action(event, fn token, %{} ->
      TenderTransaction.all(token)
    end)
  end
end
