defmodule ShopifyAPI.Shop do
  @derive {Jason.Encoder, only: [:domain]}
  defstruct domain: ""

  @typedoc """
  Type that represents a Shopify Shop with

    - domain corresponding to the full myshopify hostname for the shop
  """
  @type t :: %__MODULE__{domain: String.t()}

  @shopify_domain "myshopify.com"

  @spec post_login(ShopifyAPI.AuthToken.t() | ShopifyAPI.UserToken.t()) :: any()
  def post_login(%ShopifyAPI.AuthToken{} = token) do
    :post_login |> shop_config() |> call_post_login(token)
    # @deprecated
    :post_install |> shop_config() |> call_post_login(token)
  end

  def post_login(%ShopifyAPI.UserToken{} = token) do
    :post_login |> shop_config() |> call_post_login(token)
  end

  @spec domain_from_slug(String.t()) :: String.t()
  def domain_from_slug(slug), do: "#{slug}.#{@shopify_domain}"

  @spec slug_from_domain(String.t()) :: String.t()
  def slug_from_domain(domain), do: String.replace(domain, "." <> @shopify_domain, "")

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
