defmodule ShopifyAPI.Shop do
  @moduledoc """
  A Shopify shop, identified by its myshopify domain.

  The struct itself is barely more than that domain — the interesting parts of this module are
  the `post_login` hook and the helpers for moving between a shop's slug, domain and URI.
  `ShopifyAPI.ShopServer` caches these structs.

  ## The post_login hook

  Configure an MFA tuple to be told whenever a shop finishes authenticating:

      config :shopify_api, ShopifyAPI.Shop, post_login: {MyApp.Shop, :post_login, []}

  `post_login/1` is called with the token that was just issued — a `ShopifyAPI.AuthToken` or a
  `ShopifyAPI.UserToken` — after an install through `ShopifyAPI.Router` or a token exchange
  through `ShopifyAPI.JWTSessionToken`. It is the place to register webhooks, backfill data, or
  mark a shop active.

  > #### The hook must be a three-element tuple, and its arguments are dropped {: .warning}
  >
  > The configured MFA is invoked as `apply(module, function, [token])`. A `{module, function}`
  > pair raises, and any arguments in the third element are discarded rather than appended —
  > unlike the cache servers' callbacks, which do append them.

  A deprecated `:post_install` key is still read *in addition to* `:post_login`, and only for
  offline tokens. Configuring both calls your hook twice.
  """

  @derive {Jason.Encoder, only: [:domain]}
  defstruct domain: ""

  @typedoc """
  Type that represents a Shopify Shop with

    - domain corresponding to the full myshopify hostname for the shop
  """
  @type t :: %__MODULE__{domain: String.t()}

  @shopify_domain "myshopify.com"

  @doc """
  Invokes the configured `post_login` hook with a freshly issued token.

  Returns whatever the hook returns, or `nil` when none is configured. For a
  `ShopifyAPI.AuthToken` the deprecated `:post_install` hook is invoked afterwards as well.
  """
  @spec post_login(ShopifyAPI.AuthToken.t() | ShopifyAPI.UserToken.t()) :: any()
  def post_login(%ShopifyAPI.AuthToken{} = token) do
    :post_login |> shop_config() |> call_post_login(token)
    # @deprecated
    :post_install |> shop_config() |> call_post_login(token)
  end

  def post_login(%ShopifyAPI.UserToken{} = token) do
    :post_login |> shop_config() |> call_post_login(token)
  end

  @doc """
  Expands a shop's slug into its full myshopify domain.

  ## Examples

      iex> ShopifyAPI.Shop.domain_from_slug("acme")
      "acme.myshopify.com"

  """
  @spec domain_from_slug(String.t()) :: String.t()
  def domain_from_slug(slug), do: "#{slug}.#{@shopify_domain}"

  @doc """
  Reduces a myshopify domain to its slug.

  ## Examples

      iex> ShopifyAPI.Shop.slug_from_domain("acme.myshopify.com")
      "acme"

  """
  @spec slug_from_domain(String.t()) :: String.t()
  def slug_from_domain(domain), do: String.replace(domain, "." <> @shopify_domain, "")

  @doc """
  Builds the base `URI` for a shop, from either the struct or its domain.

  In `:dev` and `:test` the domain may carry a port (`"localhost:4040"`), so that requests can
  be pointed at a Bypass server instead of Shopify.
  """
  @spec to_uri(String.t()) :: URI.t()
  @spec to_uri(t()) :: URI.t()
  def to_uri(%_{domain: domain} = shop) when is_struct(shop, __MODULE__), do: to_uri(domain)

  # define custom to_uri for testing and dev so we can have shops that point back to ByPass URIs.
  if Mix.env() == :test or Mix.env() == :dev do
    def to_uri(myshopify_domain) do
      {domain, port} =
        if String.match?(myshopify_domain, ~r/.*:.*/) do
          [domain, str_port] = String.split(myshopify_domain, ":")
          {domain, String.to_integer(str_port)}
        else
          {myshopify_domain, 443}
        end

      %URI{scheme: ShopifyAPI.transport(), port: port, host: domain}
    end
  else
    def to_uri(myshopify_domain),
      do: %URI{scheme: ShopifyAPI.transport(), port: ShopifyAPI.port(), host: myshopify_domain}
  end

  defp shop_config(key),
    do: Application.get_env(:shopify_api, ShopifyAPI.Shop)[key]

  defp call_post_login({module, function, _}, token), do: apply(module, function, [token])
  defp call_post_login(nil, _token), do: nil
end
