defmodule ShopifyAPI.Plugs.Webhook do
  @moduledoc """
  A Plug to handle incoming webhooks from Shopify.

  This plug requires access to the unparsed request body in order to perform HMAC verification.
  As a result, it should be installed outside of your Phoenix router, and before any JSON parsing.
  In most Phoenix apps, this should be somewhere inside of your Endpoint module (`lib/your_app_web/endpoint.ex`).

  ## Options

  There are two required and one optional bit of configuration for this Plug:

  - `:prefix` - the request path for webhooks. Must be valid Plug.Router syntax.
  - `:callback` - a {mod, fun, args} tuple to be invoked for each verified webhook received.
  - `:app_name` (opt) - a default Shopify App name string to be used if one isn't present in the webhook request.

  The provided `callback` is called from the plug itself, so take care to limit the work done in the callback itself.
  If possible, enqueue a background job or otherwise handoff any further work to another asynchronous component.
  This helps reduce the likelihood of slow response times between ourselves and Shopify's webhook backend.

  ## Callback

  The configured `{mod, fun, args}` callback will be invoked for valid webhooks.
  It will be called with 4 arguments by default:

    - the matching `%ShopifyAPI.App{}` struct
    - the matching `%ShopifyAPI.Shop{}` struct
    - the string `X-Shopify-Topic` webhook header value
    - the map `payload` from the webhook body

  If you provide any additional arguments to your configured callback, they will be appended to these.

  ## Shopify App Routing

  Shopify does not send the name of an app receiving the webhook along with the payload.
  As such, there's two ways to make sure that requests are parsed and verified correctly:

  1. Append your Shopify App's name to the Webhook URL configured in Shopify.
     e.g. if your app is 'reporting-tool', make your webhook url end in '/webhooks/reporting-tool'.

  2. Specify a default `app_name` as configuration when installing the plug (see below).

  ## Example Installations

      # No default app provided -- make sure to append the app name to webhook URLs in Shopify.
      plug ShopifyAPI.Plugs.Webhook,
           prefix: "/shopify/webhooks/",
           callback: {WebhookHandler, :handle_webhook, []}

      # Default app provided -- if app name is not present in URL, defaults to "reporting-tool".
      plug ShopifyAPI.Plugs.Webhook,
           prefix: "/webhook",
           app_name: "reporting-tool",
           callback: {WebhookHandler, :handle_webhook, []}

  ## Telemetry

  This plug is instrumented using the `:telemetry` library, and emits the following events:

  - `[:shopify_api, :webhook, :start]` - emitted when beginning to process a webhook request
  - `[:shopify_api, :webhook, :stop]` - emitted when finished processing a webhook request
  - `[:shopify_api, :webhook, :exception]` - emitted if an exception occurs when processing a webhook request
  """

  import Plug.Conn
  import Plug.Crypto, only: [secure_compare: 2]

  require Logger

  alias Plug.Conn
  alias Plug.Router.Utils, as: RouterUtils

  alias ShopifyAPI.App
  alias ShopifyAPI.AppServer
  alias ShopifyAPI.ShopServer

  @supported_body_length_bytes 15_000_000

  def init(opts) do
    prefix = opts |> Keyword.fetch!(:prefix) |> RouterUtils.split()
    callback = opts |> Keyword.fetch!(:callback) |> validate_mfa()
    app_name = Keyword.get(opts, :app_name)
    %{prefix: prefix, callback: callback, app_name: app_name}
  end

  def call(%Conn{} = conn, %{} = opts) do
    if is_webhook_request?(conn, opts) do
      handle_webhook_request(conn, opts)
    else
      conn
    end
  end

  defp handle_webhook_request(%Conn{} = conn, %{} = opts) do
    start = System.monotonic_time()

    with {:ok, topic} <- fetch_topic(conn),
         {:ok, app} <- get_app(conn, opts),
         {:ok, conn, payload} <- verify_and_read_body(conn, app) do
      domain = get_domain(conn)
      shop = get_shop(domain)

      metadata = %{domain: domain, topic: topic, request_id: get_request_id(conn)}

      call_webhook_handler(conn, opts, %{
        app: app,
        topic: topic,
        payload: payload,
        domain: domain,
        shop: shop,
        metadata: metadata,
        start: start
      })
    else
      {:error, reason} ->
        Logger.debug("In webhook plug, unauthorized: #{inspect(reason)}")

        conn
        |> send_resp(401, "unauthorized")
        |> halt()
    end
  end

  def call_webhook_handler(conn, opts, params) do
    :telemetry.execute(
      [:shopify_api, :webhook, :start],
      %{time: System.system_time()},
      params.metadata
    )

    case apply_webhook(opts.callback, params.app, params.shop, params.topic, params.payload) do
      :ok ->
        :telemetry.execute(
          [:shopify_api, :webhook, :stop],
          %{duration: System.monotonic_time() - params.start},
          params.metadata
        )

        conn
        |> send_resp(200, "ok")
        |> halt()

      {:error, reason} ->
        :telemetry.execute(
          [:shopify_api, :webhook, :exception],
          %{duration: System.monotonic_time() - params.start},
          Map.merge(params.metadata, %{reason: reason})
        )

        Logger.warning("In webhook plug, errored with: #{inspect(reason)}")

        conn
        |> send_resp(500, "internal server error")
        |> halt()
    end
  end

  defp get_shop(domain) do
    case ShopServer.get(domain) do
      {:ok, shop} -> shop
      :error -> nil
    end
  end

  defp get_app(%Conn{} = conn, %{} = opts) do
    with {:ok, app_name} <- get_app_name(conn, opts) do
      case AppServer.get(app_name) do
        {:ok, app} -> {:ok, app}
        :error -> {:error, :app_not_found}
      end
    end
  end

  # First path segment after our plug's route match prefix.
  # i.e. "/webhooks/testapp" w/ prefix "/webhooks/" => "testapp"
  defp get_app_name(%Conn{path_info: path}, %{} = opts) do
    case Enum.at(path, length(opts[:prefix])) || opts[:app_name] do
      nil -> {:error, :no_app_name}
      app_name -> {:ok, app_name}
    end
  end

  # Verifies the request body with the X-Shopify-HMAC-SHA256 header
  defp verify_and_read_body(%Conn{} = conn, %App{client_secret: secret}) do
    with {:ok, shopify_hmac} <- fetch_hmac(conn),
         {:ok, body, conn} <- read_body(conn, length: @supported_body_length_bytes) do
      payload_hmac = ShopifyAPI.Security.base64_sha256_hmac(body, secret)

      if secure_compare(shopify_hmac, payload_hmac) do
        {:ok, conn, ShopifyAPI.JSONSerializer.decode!(body)}
      else
        {:error, {:hmac_mismatch, shopify_hmac, payload_hmac}}
      end
    end
  end

  # Apply the webhook callback in a context where we can catch exceptions.
  defp apply_webhook({mod, fun, args}, app, shop, topic, payload) do
    apply(mod, fun, [app, shop, topic, payload | args])
  catch
    :exit, reason -> {:error, reason}
    :error, reason -> {:error, {reason, __STACKTRACE__}}
  end

  # A webhook request both matches the configured path prefix and has the
  # appropriate X-Shopify-* headers. All other requests should be ignored.
  defp is_webhook_request?(%Conn{path_info: path} = conn, %{prefix: prefix} = _opts),
    do: is_post?(conn) and matches?(prefix, path)

  defp is_post?(%Conn{method: method}), do: method == "POST"

  defp matches?([h | expected], [h | actual]), do: matches?(expected, actual)
  defp matches?([], _), do: true
  defp matches?(_, _), do: false

  defp fetch_hmac(conn), do: get_header(conn, "x-shopify-hmac-sha256")
  defp fetch_topic(conn), do: get_header(conn, "x-shopify-topic")

  defp get_domain(conn) do
    case get_header(conn, "x-shopify-shop-domain") do
      {:ok, domain} -> domain
      {:error, _} -> nil
    end
  end

  defp get_header(%Conn{} = conn, key) when is_binary(key) do
    case get_req_header(conn, key) do
      [value | _] -> {:ok, String.trim(value)}
      [] -> {:error, "header not found #{key}"}
    end
  end

  defp validate_mfa({mod, fun, args} = mfa)
       when is_atom(mod) and is_atom(fun) and is_list(args),
       do: mfa

  defp validate_mfa(value),
    do: raise(ArgumentError, "expected :callback to be {Mod, Fun, Args}, got: #{inspect(value)}")

  # This is set by the `Plug.RequestID` plug
  defp get_request_id(%Conn{req_headers: headers}) do
    Enum.find_value(headers, fn {key, value} ->
      key == "x-request-id" and value
    end)
  end
end
