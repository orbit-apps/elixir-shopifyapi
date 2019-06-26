defmodule ShopifyAPI.REST.User do
  @moduledoc """
  ShopifyAPI REST API User resource
  """

  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST

  @doc """
  Get a single user.

  ## Example

      iex> ShopifyAPI.REST.User.get(auth, integer)
      {:ok, { "user" => %{} }}
  """
  def get(%AuthToken{} = auth, user_id), do: REST.get(auth, "users/#{user_id}.json")

  @doc """
  Return a list of all users.

  ## Example

      iex> ShopifyAPI.REST.User.all(auth)
      {:ok, { "users" => [] }}
  """
  def all(%AuthToken{} = auth), do: REST.get(auth, "users.json")

  @doc """
  Get the currently logged-in user.

  ## Example

      iex> ShopifyAPI.REST.User.current(auth)
      {:ok, { "user" => %{} }}
  """
  def current(%AuthToken{} = auth), do: REST.get(auth, "users/current.json")
end
