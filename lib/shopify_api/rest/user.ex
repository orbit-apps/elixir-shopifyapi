defmodule ShopifyApi.Rest.User do
  @moduledoc """
  ShopifyApi REST API User resource
  """

  alias ShopifyApi.AuthToken
  alias ShopifyApi.Rest.Request

  @doc """
  Get a single user.

  ## Example

      iex> ShopifyApi.Rest.User.get(auth, integer)
      {:ok, { "user" => %{} }}
  """
  def get(%AuthToken{} = auth, user_id) do
    Request.get(auth, "users/#{user_id}.json")
  end

  @doc """
  Return a list of all users.

  ## Example

      iex> ShopifyApi.Rest.User.all(auth)
      {:ok, { "users" => [] }}
  """
  def all(%AuthToken{} = auth) do
    Request.get(auth, "users.json")
  end

  @doc """
  Get the currently logged-in user.

  ## Example

      iex> ShopifyApi.Rest.User.current(auth)
      {:ok, { "user" => %{} }}
  """
  def current(%AuthToken{} = auth) do
    Request.get(auth, "users/current.json")
  end
end
