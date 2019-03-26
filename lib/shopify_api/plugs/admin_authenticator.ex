defmodule ShopifyAPI.Plugs.AdminAuthenticator do
  @moduledoc """
  """
  import Plug.Conn
  require Logger

  alias Plug.Conn

  alias ShopifyAPI.AppServer
  alias ShopifyAPI.AuthTokenServer
  alias ShopifyAPI.ConnHelpers
  alias ShopifyAPI.Security
  alias ShopifyAPI.ShopServer

  def init(opts), do: opts

  def call(conn, options) do
    with {:ok, app} <- ConnHelpers.fetch_shopify_app(conn),
         true <- ConnHelpers.verify_params_with_hmac(app, conn.query_params) do
      conn
      |> ConnHelpers.assign_app()
      |> ConnHelpers.assign_shop()
      |> ConnHelpers.assign_auth_token()
    else
      res ->
        Logger.info("#{__MODULE__} failed authorized with: #{inspect(res)}")

        conn
        |> Conn.resp(401, "Not Authorized.")
        |> Conn.halt()
    end
  end
end
