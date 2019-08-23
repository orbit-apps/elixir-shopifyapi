defmodule ShopifyAPI.Plugs.Webhook do
  @moduledoc """
  The ShopifyAPI.Plugs.Webhook plug handles incoming Shopify Webhook calls.  The incoming requests
  get fired off to the :shopify_api :webhook_filter {module, function, _} setting getting passed a
  ShopifyAPI.EventPipe.Event.t.
  """
  import Plug.Conn
  require Logger

  alias Plug.Conn
  alias ShopifyAPI.{ConnHelpers, JSONSerializer, Security}
  alias ShopifyAPI.EventPipe.Event

  def init(opts), do: opts

  def call(conn, options) do
    mount = Keyword.get(options, :mount)

    if String.starts_with?(conn.request_path, mount) do
      conn
      # params have not been parsed yet, calling assign_app/0 tries the conn.params first which will error
      |> ConnHelpers.assign_app(ConnHelpers.app_name_from_path(conn))
      |> ConnHelpers.assign_shop()
      |> ConnHelpers.assign_auth_token()
      |> ConnHelpers.assign_event()
      |> verify_and_parse()
      |> fire_callback(Application.get_env(:shopify_api, :webhook_filter))
      |> send_response()
    else
      conn
    end
  end

  defp generate_event(conn) do
    %Event{
      destination: "client",
      app: conn.assigns.app,
      shop: Map.get(conn.assigns, :shop),
      action: conn.assigns.shopify_event,
      object: conn.body_params,
      metadata: metadata()
    }
  end

  defp metadata do
    Enum.into(Logger.metadata(), %{})
  end

  defp verify_and_parse(conn) do
    with %{client_secret: secret} <- conn.assigns.app,
         {:ok, content, conn} <- read_body(conn),
         signature <- ConnHelpers.hmac_from_header(conn),
         ^signature <- Security.base64_sha256_hmac(content, secret),
         {:ok, params} <- JSONSerializer.decode(content) do
      {:ok, Map.put(conn, :body_params, params)}
    else
      _ -> {:error, conn}
    end
  end

  defp fire_callback({:ok, conn}, nil) do
    Logger.error(
      "#{__MODULE__} failure to fire callback, no :shopify_api, :webhook_filter configuration"
    )

    {:error, conn}
  end

  defp fire_callback({:ok, conn}, {module, function, _}) do
    apply(module, function, [generate_event(conn)])
    {:ok, conn}
  end

  defp fire_callback({_, conn}, _), do: {:error, conn}

  defp send_response({:ok, conn}) do
    conn
    |> send_resp(200, "ok.")
    |> Conn.halt()
  end

  defp send_response({_, conn}) do
    conn
    |> put_resp_content_type("text/plain")
    # TODO should we be sending 401 here?
    |> send_resp(401, "Not Authorized")
    |> halt()
  end
end
