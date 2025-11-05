defmodule ShopifyAPI.JWTSessionToken do
  @doc """
  Handles validation, data fetching, and exchange for Shopify Session Tokens.

  [Shopify documentation](https://shopify.dev/docs/apps/build/authentication-authorization/session-tokens/set-up-session-tokens)
  """
  require Logger

  @spec verify(String.t(), String.t()) ::
          {valid? :: boolean(), jwt :: JOSE.JWT.t(), jws :: JOSE.JWS.t()}
  def verify(token, client_secret) do
    jwk = JOSE.JWK.from_oct(client_secret)
    JOSE.JWT.verify_strict(jwk, ["HS256"], token)
  end

  @spec app(JOSE.JWT.t() | String.t()) :: {:ok, ShopifyAPI.App.t()} | {:error, any()}
  def app(%JOSE.JWT{fields: %{"aud" => client_id}}) do
    case ShopifyAPI.AppServer.get_by_client_id(client_id) do
      {:ok, _} = resp -> resp
      _ -> {:error, "Audience claim is not a valid App clientId."}
    end
  end

  def app(token) when is_binary(token), do: token |> JOSE.JWT.peek_payload() |> app()

  @spec myshopify_domain(JOSE.JWT.t()) :: {:ok, String.t()} | {:error, any()}
  def myshopify_domain(%JOSE.JWT{fields: %{"dest" => shop_url}}) do
    shop_url
    |> URI.parse()
    |> Map.get(:host)
    |> case do
      shop_name when is_binary(shop_name) -> {:ok, shop_name}
      _ -> {:error, "Shop name not found"}
    end
  end

  def myshopify_domain(_), do: {:error, "Invalid user token or shop name not found"}

  @spec user_id(JOSE.JWT.t()) :: {:ok, integer()} | {:error, any()}
  def user_id(%JOSE.JWT{fields: %{"sub" => user_id}}),
    do: {:ok, String.to_integer(user_id)}

  def user_id(_),
    do: {:error, "Invalid user token or no id"}
end
