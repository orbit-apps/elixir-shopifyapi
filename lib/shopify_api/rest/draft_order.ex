defmodule ShopifyAPI.REST.DraftOrder do
  @moduledoc """
  ShopifyAPI REST API DraftOrder resource

  This resource contains methods for working with draft orders in Shopify
  """
  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST.Request

  @doc """
  Create a new draft order with the provided attributes

  ## Example

      iex> ShopifyAPI.REST.DraftOrder.create(auth_token, %{draft_order: %{}})
      {:ok, %{"draft_order" => %{...}}}
  """
  def create(%AuthToken{} = auth, %{draft_order: %{}} = draft_order),
    do: Request.post(auth, "draft_orders.json", draft_order)

  @doc """
  Update a draft order

  ## Example

      iex> ShopifyAPI.REST.DraftOrder.update(auth_token, %{draft_order: %{}})
      {:ok, %{"draft_order" => %{...}}}

      To add a note to a draft order:
      %{
        draft_order: %{
          id: 994118539,
          note: "Customer contacted us about a custom engraving on the item"
        }
      }
  """
  def update(%AuthToken{} = auth, %{draft_order: %{id: draft_order_id}} = draft_order),
    do: Request.put(auth, "draft_orders/#{draft_order_id}.json", draft_order)

  @doc """
  Retrieve a list of all draft orders

  ## Example

      iex> ShopifyAPI.REST.DraftOrder.all(auth)
      {:ok, %{"draft_orders" => []}}
  """
  def all(%AuthToken{} = auth), do: Request.get(auth, "draft_orders.json")

  @doc """
  Retrieve a specific draft order

  ## Example

      iex> ShopifyAPI.REST.DraftOrder.get(auth, integer)
      {:ok, %{"draft_order" => %{...}}}
  """
  def get(%AuthToken{} = auth, draft_order_id),
    do: Request.get(auth, "draft_orders/#{draft_order_id}.json")

  @doc """
  Retrieve a count of all draft orders

  ## Example

      iex> ShopifyAPI.REST.DraftOrder.count(auth)
      {:ok, %{count: integer}}
  """
  def count(%AuthToken{} = auth), do: Request.get(auth, "draft_orders/count.json")

  @doc """
  Send an invoice for a draft order

  ## Example

      iex> ShopifyAPI.REST.DraftOrder.send_invoice(auth, %{draft_order_invoice: %{}})
      {:ok, %{"draft_order_invoice" => %{...}}}

      To send the default invoice:
      %{
        draft_order_invoice: %{}
      }

      To send a customized invoice:
      %{
        draft_order_invoice: %{
          to: "first@example.com",
          from: "steve@apple.com",
          bcc: [
            "steve@apple.com"
          ],
          subject: "Apple Computer Invoice",
          custom_message: "Thank you for ordering!"
        }
      }
  """
  def send_invoice(
        %AuthToken{} = auth,
        draft_order_id,
        %{draft_order_invoice: %{}} = draft_order_invoice
      ),
      do:
        Request.post(
          auth,
          "draft_orders/#{draft_order_id}/send_invoice.json",
          draft_order_invoice
        )

  @doc """
  Delete a draft order

  ## Example

      iex> ShopifyAPI.REST.DraftOrder.delete(auth, integer)
      {:ok, %{}}
  """
  def delete(%AuthToken{} = auth, draft_order_id),
    do: Request.delete(auth, "draft_orders/#{draft_order_id}.json")

  @doc """
  Complete a draft order

  ## Example

      To complete a draft order, marking it as paid:
      iex> ShopifyAPI.REST.DraftOrder.complete(auth, integer, false)

      To complete a draft order, marking it as pending:
      iex> ShopifyAPI.REST.DraftOrder.complete(auth, integer, true)

      {:ok, %{"draft_order", %{...}}}
  """
  def complete(%AuthToken{} = auth, draft_order_id, params),
    do:
      Request.put(
        auth,
        "draft_orders/#{draft_order_id}/complete.json?" <>
          URI.encode_query(%{"payment_pending" => params}),
        %{}
      )
end
