defmodule ShopifyAPI.REST.Redirect do
  @moduledoc """
  Shopify REST API Redirect resources
  """

  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST

  @doc """
  Get a list of all the redirects.

  ## Example

    iex> ShopifyAPI.REST.Redirect.all(auth)
    {:ok, [] = redirects}
  """
  def all(%AuthToken{} = auth, params \\ [], options \\ []),
    do: REST.get(auth, "redirects.json", params, options)

  @doc """
  Return a single redirect.

  ## Example

    iex> ShopifyAPI.REST.Redirect.get(auth, integer)
    {:ok, %{} = redirect}
  """
  def get(%AuthToken{} = auth, redirect_id, params \\ [], options \\ []),
    do:
      REST.get(
        auth,
        "redirects/#{redirect_id}.json",
        params,
        Keyword.merge([pagination: :none], options)
      )

  @doc """
  Return a count of redirects.

  ## Example

    iex> ShopifyAPI.REST.Redirect.count(auth)
    {:ok, integer = count}
  """
  def count(%AuthToken{} = auth, params \\ [], options \\ []),
    do:
      REST.get(auth, "redirects/count.json", params, Keyword.merge([pagination: :none], options))

  @doc """
  Update a redirect.

  ## Expected Shape

  ### Request Redirect Map Shape Example
    %{
      id: 668809255,
      path: "/tiger"
    }

  ### Response Map Shape Example
    %{
      "id": 668809255,
      "path": "/tiger",
      "target": "/pages/macosx"
    }

  ## Example

    iex> ShopifyAPI.REST.Redirect.update(auth, map)
    {:ok, %{} = redirect}
  """
  def update(%AuthToken{} = auth, %{"redirect" => %{"id" => redirect_id} = redirect}),
    do: update(auth, %{redirect: Map.put(redirect, :id, redirect_id)})

  def update(%AuthToken{} = auth, %{redirect: %{id: redirect_id}} = redirect),
    do: REST.put(auth, "redirects/#{redirect_id}.json", redirect)

  @doc """
  Delete a redirect.

  ## Example

      iex> ShopifyAPI.REST.Redirect.delete(auth, integer)
      {:ok, 200 }
  """
  def delete(%AuthToken{} = auth, redirect_id),
    do: REST.delete(auth, "redirects/#{redirect_id}.json")

  @doc """
  Create a new redirect.

  ## Expected Shape

  ###Request Redirect Map Shape Example
    %{
      path: "/ipod",
      target: "/pages/itunes"
    }

  ### Response Map Shape Example
    %{
        "id": 979034144,
        "path": "/ipod",
        "target": "/pages/itunes"
    }

  ## Example

      iex> ShopifyAPI.REST.Redirect.create(auth, map)
      {:ok, %{} = redirect}
  """
  def create(%AuthToken{} = auth, %{"redirect" => %{} = redirect}),
    do: create(auth, %{redirect: redirect})

  def create(%AuthToken{} = auth, %{redirect: %{}} = redirect),
    do: REST.post(auth, "redirects.json", redirect)
end
