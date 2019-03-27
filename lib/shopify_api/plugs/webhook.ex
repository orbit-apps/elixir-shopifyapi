defmodule ShopifyAPI.Plugs.Webhook do
  @moduledoc """
  The ShopifyAPI.Plugs.Webhook plug handles incoming Shopify Webhook calls.  The incoming requests
  get fired off to the :shopify_api :webhook_filter {module, function, _} setting getting passed a
  ShopifyAPI.EventPipe.Event.t.
  """
  import Plug.Conn
  require Logger

  alias Plug.Conn
  alias ShopifyAPI.{ConnHelpers, Security}
  alias ShopifyAPI.EventPipe.Event

  def init(opts), do: opts

  def call(conn, options) do
    mount = Keyword.get(options, :mount)

    if String.starts_with?(conn.request_path, mount) do
      conn
      |> ConnHelpers.assign_app()
      |> ConnHelpers.assign_shop()
      |> ConnHelpers.assign_auth_token()
      |> ConnHelpers.assign_event()
      |> verify_and_parse()
      |> case do
        {:ok, conn} ->
          {module, function, _} = Application.get_env(:shopify_api, :webhook_filter)
          apply(module, function, [generate_event(conn)])

          conn
          |> Conn.resp(200, "ok.")
          |> Conn.halt()

        _ ->
          conn
      end
    else
      conn
    end
  end

  defp generate_event(conn) do
    %Event{
      destination: :client,
      app: conn.assigns.app,
      shop: Map.get(conn.assigns, :shop),
      action: conn.assigns.shopify_event,
      object: conn.body_params
    }
  end

  defp verify_and_parse(conn) do
    with %{client_secret: secret} <- conn.assigns.app,
         {:ok, content, conn} <- read_body(conn),
         signature <- List.first(get_req_header(conn, "x-shopify-hmac-sha256")),
         _ <-
           Logger.info(
             "#{__MODULE__} actual body hmac is: #{
               inspect(Security.base64_sha256_hmac(content, secret))
             }"
           ),
         ^signature <- Security.base64_sha256_hmac(content, secret),
         {:ok, params} <- Poison.decode(content) do
      {:ok, Map.put(conn, :body_params, params)}
    else
      _ ->
        {:error,
         conn
         |> put_resp_content_type("text/plain")
         |> send_resp(401, "Not Authorized")
         |> halt}
    end
  end
end
