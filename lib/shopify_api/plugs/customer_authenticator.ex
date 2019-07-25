defmodule ShopifyAPI.Plugs.CustomerAuthenticator do
  @moduledoc """
  The Shopify.Plugs.CustomerAuthenticator plug allows for authentication of a customer call being made from a Shopify shop with a signed payload.

  ## Liquid Template

  You can create the payload for and signature for that this plug will consume with the following `liquid` template:
  ```liquid
    {% assign auth_expiry = "now" | date: "%s" | plus: 86400 | date: "%Y-%m-%dT%H:%M:%S.%L%z" %}
    {% capture json_string %}
      {"email":"{{ customer.email }}","id":"{{ customer.id }}","expiry":"{{ auth_expiry }}"}
    {% endcapture %}
    {% assign AUTH_PAYLOAD = json_string | strip %}
    {% assign AUTH_SIGNATURE = AUTH_PAYLOAD | hmac_sha256: settings.secret %}
  ```
  The payload itself can be modified to include additional fields so long as it is valid json.
  The original intent was for this to generate a JWT, but Liquid does not include base64 encoding.


  ## Configuring Secrets

  Include a shared secret in your Elixir config and in your Shopify settings. You can provide a list to make rotating secrets easier.

  ```elixir
  # config.exs
  config :shopify_api, :customer_api_secret_keys, ["new_secret", "old_secret"]
  ```

  ## Example Usage

  ```elixir
  pipeline :customer_api do
    plug ShopifyAPI.Plugs.CustomerAuthenticator
  end

  scope "/api", YourAppWeb do
    pipe_through :browser
    pipe_through :customer_api
    get "/", CustomerAPIController, :index
  end
  ```
  """

  import Plug.Conn

  alias ShopifyAPI.Security
  alias ShopifyAPI.JSONSerializer

  def init(_opts) do
    %{customer_api_secret_keys: Application.get_env(:shopify_api, :customer_api_secret_keys)}
  end

  def call(
        %{params: %{"auth_payload" => payload, "auth_signature" => signature}} = conn,
        opts
      ) do
    with :ok <- validate_signature(payload, signature, customer_api_secret_keys()),
         {:ok, auth_context} <- parse_payload(payload) do
      conn
      |> assign(:auth_context, auth_context)
    else
      :error ->
        send_unauthorized_response(conn, "Authorization failed")

      {:error, _} ->
        send_unauthorized_response(conn, "Could not parse auth_payload")
    end
  end

  def call(conn, _), do: send_unauthorized_response(conn, "Authorization failed")

  def valid_signature?(auth_payload, signature, secrets) when is_list(secrets) do
    Enum.any?(secrets, fn secret ->
      signature == Security.base16_sha256_hmac(auth_payload, secret)
    end)
  end

  def validate_signature(auth_payload, signature, secret),
    do: validate_signature(auth_payload, signature, [secret])

  defp parse_payload(payload) do
    JSONSerializer.decode(payload)
  end

  defp customer_api_secret_keys do
    Application.get_env(:shopify_api, :customer_api_secret_keys, [])
  end

  defp send_unauthorized_response(conn, message) do
    conn
    |> resp(401, message)
    |> halt()
  end
end
