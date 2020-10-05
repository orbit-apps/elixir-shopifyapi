defmodule ShopifyAPI.REST.Redirect do
  @moduledoc false
  @moduledoc """
  Shopify REST API Redirect resources
  """

  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST
  alias ShopifyAPI.REST.Redirect

  defstruct id: nil,
            path: nil,
            target: nil

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

  ## Example

    iex> ShopifyAPI.REST.Redirect.update(auth, map)
    {:ok, %{} = redirect}
  """
  def update(%AuthToken{} = auth, %{"redirect" => %{} = redirect}) do
    atomized_map =
      for {key, val} <- redirect,
          into: %{},
          do: {if(is_binary(key), do: String.to_atom(key), else: key), val}

    update(auth, %{redirect: atomized_map})
  end

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


    %{
      path: "/ipod",
      target: "/pages/itunes"
    }


    %{
        "id": 979034144,
        "path": "/ipod",
        "target": "/pages/itunes"
    }

  ## Example

      iex> ShopifyAPI.REST.Redirect.create(auth, map)
      {:ok, %{} = redirect}
  """
  def create(%AuthToken{} = auth, %{"redirect" => %{} = redirect}) do
    atomized_map =
      for {key, val} <- redirect,
          into: %{},
          do: {if(is_binary(key), do: String.to_atom(key), else: key), val}

    create(auth, %{redirect: atomized_map})
  end

  def create(%AuthToken{} = auth, %{redirect: %{}} = redirect),
    do: REST.post(auth, "redirects.json", redirect)
end
