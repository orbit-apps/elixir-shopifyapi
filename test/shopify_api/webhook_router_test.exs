defmodule Test.ShopifyApi.EventPipe.WebhookEventProcessor do
  @moduledoc """
  Test processor for webhook events.
  """
  require Logger
  use GenStage

  alias ShopifyApi.EventPipe.WebhookEventQueue

  @doc "Starts the consumer."
  def start_link() do
    Logger.info("Starting #{__MODULE__}...")
    GenStage.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    # Starts a permanent subscription to the broadcaster
    # which will automatically start requesting items.
    {
      :consumer,
      :ok,
      subscribe_to: [WebhookEventQueue]
    }
  end

  def handle_events(events, _from, state) do
    for event <- events do
      Logger.info("#{__MODULE__} is processing an event #{inspect(event)}")
    end

    {:noreply, [], state}
  end
end

defmodule Test.ShopifyApi.WebhookRouterTest do
  use ExUnit.Case
  use Plug.Test

  alias Plug.{Conn, Parsers}
  alias ShopifyApi.{AppServer, ShopServer, Security, WebhookRouter}
  alias Test.ShopifyApi.EventPipe.WebhookEventProcessor

  def parse(conn, opts \\ []) do
    opts = Keyword.put_new(opts, :parsers, [Parsers.URLENCODED, Parsers.MULTIPART])
    Parsers.call(conn, Parsers.init(opts))
  end

  @app_name "test"
  @client_secret "test"
  @post_body "{\"test\": \"test\"}"
  @shop_domain "shop.example.com"
  @shopify_topic "test"

  setup do
    WebhookEventProcessor.start_link()

    AppServer.set(@app_name, %{
      name: @app_name,
      client_secret: @client_secret
    })

    ShopServer.set(%{domain: @shop_domain})
  end

  describe "with App and Store" do
    setup do
      conn =
        conn(:post, "/" <> @app_name, @post_body)
        |> Conn.put_req_header("x-shopify-shop-domain", @shop_domain)
        |> Conn.put_req_header("x-shopify-topic", @shopify_topic)
        |> Conn.put_req_header(
          "x-shopify-hmac-sha256",
          Security.base64_sha256_hmac(@post_body, @client_secret)
        )
        |> parse

      conn = call(WebhookRouter, conn)

      %{conn: conn}
    end

    test "it returns 200", %{conn: conn} do
      assert conn.status == 200
    end

    test "it parses the body", %{conn: conn} do
      assert {:ok, conn.body_params} == Poison.decode(@post_body)
    end

    test "sets the App on the conn", %{conn: conn} do
      assert conn.assigns[:app].name == @app_name
    end

    test "sets the Shop on the conn", %{conn: conn} do
      assert conn.assigns[:shop].domain == @shop_domain
    end

    test "sets the Shopify Event on the conn", %{conn: conn} do
      assert conn.assigns[:shopify_event] == @shopify_topic
    end
  end

  defp call(mod, conn) do
    mod.call(conn, [])
  end
end
