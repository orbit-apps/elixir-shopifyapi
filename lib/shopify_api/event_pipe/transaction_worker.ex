defmodule ShopifyAPI.EventPipe.TransactionWorker do
  @moduledoc """
  Worker for processing Transactions
  """
  import ShopifyAPI.EventPipe.Worker
  alias ShopifyAPI.REST.Transaction

  def perform(%{action: "create", object: _, token: _} = event) do
    execute_action(event, fn token, %{object: transaction} ->
      Transaction.create(token, transaction)
    end)
  end
end
