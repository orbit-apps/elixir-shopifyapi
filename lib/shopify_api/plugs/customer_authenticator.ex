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

  The payload itself can be modified to include additional fields so long as it is valid json and contains the `expiry`.
  The original intent was for this to generate a JWT, but Liquid does not include base64 encoding.

  Include the payload and signatures in rest calls:



  Include the payload and signatures in a form:

  ```liquid
  <input
    type="hidden"
    name="auth_payload"
    value="{{ AUTH_PAYLOAD }}"
  >

   <input
    type="hidden"
    name="auth_signature"
    value="{{ AUTH_SIGNATURE }}"
  >
  ```

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

  alias ShopifyAPI.JSONSerializer
  alias ShopifyAPI.Security

  def init(_opts) do
    %{customer_api_secret_keys: Application.get_env(:shopify_api, :customer_api_secret_keys)}
  end

  def call(
        %{params: %{"auth_payload" => payload, "auth_signature" => signature}} = conn,
        _opts
      ) do
    now = DateTime.utc_now()

    with :ok <- validate_signature(payload, signature, customer_api_secret_keys()),
         {:ok, auth_context} <- parse_payload(payload),
         :ok <- validate_expiry(auth_context, now) do
      assign(conn, :auth_payload, auth_context)
    else
      error -> handle_error(conn, error)
    end
  end

  def call(conn, _), do: send_unauthorized_response(conn, "Authorization failed")

  defp validate_signature(auth_payload, signature, secrets) when is_list(secrets) do
    secrets
    |> Enum.any?(fn secret ->
      signature == Security.base16_sha256_hmac(auth_payload, secret)
    end)
    |> case do
      true -> :ok
      false -> :bad_signature
    end
  end

  defp validate_signature(auth_payload, signature, secret),
    do: validate_signature(auth_payload, signature, [secret])

  defp validate_expiry(%{"expiry" => expiry_string}, now) do
    with {:ok, expiry_datetime, _} <- DateTime.from_iso8601(expiry_string),
         :lt <- DateTime.compare(now, expiry_datetime) do
      :ok
    else
      {:error, _} -> :invalid_expiry
      _ -> :expired
    end
  end

  defp validate_expiry(_auth_context, _now) do
    :no_expiry
  end

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

  defp handle_error(conn, :no_expiry),
    do: send_unauthorized_response(conn, "A valid expiry must be included in auth_payload")

  defp handle_error(conn, :invalid_expiry),
    do:
      send_unauthorized_response(conn, "A valid ISO8601 expiry must be included in auth_payload")

  defp handle_error(conn, :expired),
    do: send_unauthorized_response(conn, "auth_payload has expired")

  defp handle_error(conn, :bad_signature),
    do: send_unauthorized_response(conn, "Authorization failed")

  defp handle_error(conn, {:error, _}),
    do: send_unauthorized_response(conn, "Could not parse auth_payload")

  defp handle_error(conn, {:error, _, _}),
    do: send_unauthorized_response(conn, "Could not parse auth_payload")

  defp handle_error(conn, _error) do
    conn
    |> resp(500, "Unhandled Error")
    |> halt()
  end
end
