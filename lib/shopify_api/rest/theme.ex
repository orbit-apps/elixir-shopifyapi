defmodule ShopifyAPI.REST.Theme do
  @moduledoc """
  ShopifyAPI REST API Theme resource
  """

  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST

  @doc """
  Get a single theme.

  ## Example

      iex> ShopifyAPI.REST.Theme.get(auth, integer)
      {:ok, %{} = theme}
  """
  def get(%AuthToken{} = auth, theme_id, params \\ [], options \\ []),
    do:
      REST.get(
        auth,
        "themes/#{theme_id}.json",
        params,
        Keyword.merge([pagination: :none], options)
      )

  @doc """
  Return a list of all themes.

  ## Example

      iex> ShopifyAPI.REST.Theme.all(auth)
      {:ok, [] = themes}
  """
  def all(%AuthToken{} = auth, params \\ [], options \\ []),
    do: REST.get(auth, "themes.json", params, Keyword.merge([pagination: :none], options))

  @doc """
  Update a theme.

  ## Example

    iex> ShopifyAPI.REST.Theme.update(auth, map)
    {:ok, %{} = theme}
  """
  def update(%AuthToken{} = auth, %{"theme" => %{"id" => theme_id} = theme}),
    do: update(auth, %{theme: Map.put(theme, :id, theme_id)})

  def update(%AuthToken{} = auth, %{theme: %{id: theme_id}} = theme),
    do: REST.put(auth, "themes/#{theme_id}.json", theme)

  @doc """
  Delete a theme.

  ## Example

      iex> ShopifyAPI.REST.Theme.delete(auth, integer)
      {:ok, 200 }
  """
  def delete(%AuthToken{} = auth, theme_id),
    do: REST.delete(auth, "themes/#{theme_id}.json")

  @doc """
  Create a new theme.

  ## Example

      iex> ShopifyAPI.REST.Theme.create(auth, map)
      {:ok, %{} = theme}
  """
  def create(%AuthToken{} = auth, %{"theme" => %{} = theme}),
    do: create(auth, %{theme: theme})

  def create(%AuthToken{} = auth, %{theme: %{}} = theme),
    do: REST.post(auth, "themes.json", theme)
end
