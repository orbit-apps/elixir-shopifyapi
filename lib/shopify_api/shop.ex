defmodule ShopifyAPI.Shop do
  alias ShopifyAPI.AuthToken

  @derive {Jason.Encoder, only: [:domain, :app_data]}
  defstruct domain: "",
            app_data: %{}

  @typedoc """
      Type that represents a Shopify Shop with

        - domain corresponding to the full URL for the shop
  """
  @type t :: %__MODULE__{
          domain: String.t(),
          app_data: map()
        }

  @spec post_install(AuthToken.t()) :: any()
  def post_install(%AuthToken{} = token) do
    :post_install
    |> shop_config
    |> call_post_install(token)
  end

  defp shop_config(key),
    do: Application.get_env(:shopify_api, ShopifyAPI.Shop)[key]

  defp call_post_install({module, function, _}, token), do: apply(module, function, [token])
  defp call_post_install(nil, _token), do: nil
end
