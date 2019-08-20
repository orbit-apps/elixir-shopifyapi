defmodule ShopifyAPI.GraphQL.TelemetryTest do
  use ExUnit.Case

  alias HTTPoison.Error
  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.GraphQL.{Response, Telemetry}

  @module "module"
  @time 1202

  setup _context do
    token = %AuthToken{
      token: "1234",
      shop_name: "localhost"
    }

    {:ok, %{auth_token: token}}
  end

  describe "Telemetry send/4" do
    test "when graphql response is succesful", %{auth_token: token} do
      assert :ok == Telemetry.send(@module, token, @time, {:ok, %Response{response: "response"}})
    end

    test "when graphql request fails", %{auth_token: token} do
      assert :ok ==
               Telemetry.send(@module, token, @time, {:error, %Response{response: "response"}})
    end

    test "when graphql request errors out", %{auth_token: token} do
      assert :ok == Telemetry.send(@module, token, @time, {:error, %Error{reason: "reason"}})
    end
  end
end
