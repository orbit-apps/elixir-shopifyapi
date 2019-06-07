defmodule ShopifyAPI.REST.PriceRule do
  @moduledoc """
  ShopifyAPI REST API PriceRule resource
  """

  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST

  @doc """
  Create a price rule.

  ## Example

      iex> ShopifyAPI.REST.PriceRule.create(auth, map)
      {:ok, { "price_rule" => %{} }}
  """
  def create(%AuthToken{} = auth, %{price_rule: %{}} = price_rule),
    do: REST.post(auth, "price_rules.json", price_rule)

  @doc """
  Update an existing price rule.

  ## Example

      iex> ShopifyAPI.REST.PriceRule.update(auth, map)
      {:ok, { "price_rule" => %{} }}
  """
  def update(%AuthToken{} = auth, %{price_rule: %{id: price_rule_id}} = price_rule),
    do: REST.put(auth, "price_rules/#{price_rule_id}.json", price_rule)

  @doc """
  Return a list of all price rules.

  ## Example

      iex> ShopifyAPI.REST.PriceRule.all(auth)
      {:ok, { "price_rules" => [] }}
  """
  def all(%AuthToken{} = auth), do: REST.get(auth, "price_rules.json")

  @doc """
  Get a single price rule.

  ## Example

      iex> ShopifyAPI.REST.PriceRule.get(auth, integer)
      {:ok, { "price_rule" => %{} }}
  """
  def get(%AuthToken{} = auth, price_rule_id),
    do: REST.get(auth, "price_rules/#{price_rule_id}.json")

  @doc """
  Delete a price rule.

  ## Example

      iex> ShopifyAPI.REST.PriceRule.delete(auth, string)
      {:ok, 204 }}
  """
  def delete(%AuthToken{} = auth, price_rule_id),
    do: REST.delete(auth, "price_rules/#{price_rule_id}.json")
end
