defmodule ShopifyAPI.REST.Theme do
  @moduledoc """
  ShopifyAPI REST API Theme resource
  """

  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST.Request

  @doc """
  Get a single theme.

  ## Example

      iex> ShopifyAPI.REST.Theme.get(auth, integer)
      {:ok, { "theme" => %{} }}
  """
  def get(%AuthToken{} = auth, theme_id, params \\ %{}),
    do: Request.get(auth, "themes/#{theme_id}.json?" <> URI.encode_query(params))

  @doc """
  Return a list of all themes.

  ## Example

      iex> ShopifyAPI.REST.Theme.all(auth)
      {:ok, { "themes" => [] }}
  """
  def all(%AuthToken{} = auth, params \\ %{}),
    do: Request.get(auth, "themes.json?" <> URI.encode_query(params))

  @doc """
  Update a theme.

  ## Example

    iex> ShopifyAPI.REST.Theme.update(auth, map)
    {:ok, %{ "theme" => %{} }}
  """
  def update(%AuthToken{} = auth, %{"theme" => %{"id" => theme_id} = theme}),
    do: update(auth, %{theme: theme |> Map.put(:id, theme_id)})

  def update(%AuthToken{} = auth, %{theme: %{id: theme_id}} = theme),
    do: Request.put(auth, "themes/#{theme_id}.json", theme)

  @doc """
  Delete a theme.

  ## Example

      iex> ShopifyAPI.REST.Theme.delete(auth, integer)
      {:ok, 200 }
  """
  def delete(%AuthToken{} = auth, theme_id),
    do: Request.delete(auth, "themes/#{theme_id}.json")

  @doc """
  Create a new theme.

  ## Example

      iex> ShopifyAPI.REST.Theme.create(auth, map)
      {:ok, %{ "theme" => %{} }}
  """
  def create(%AuthToken{} = auth, %{"theme" => %{} = theme}),
    do: create(auth, %{theme: theme})

  def create(%AuthToken{} = auth, %{theme: %{}} = theme),
    do: Request.post(auth, "themes.json", theme)
end
