defmodule ShopifyAPI.GraphQL.TelemetryTest do
  use ExUnit.Case

  import ShopifyAPI.SessionTokenSetup

  alias HTTPoison.Error
  alias ShopifyAPI.GraphQL.{Response, Telemetry}

  @module "module"
  @time 1202

  setup [:offline_token]

  describe "Telemetry send/4" do
    test "when graphql response is succesful", %{offline_token: token} do
      assert :ok == Telemetry.send(@module, token, @time, {:ok, %Response{response: "response"}})
    end

    test "when graphql request fails", %{offline_token: token} do
      assert :ok ==
               Telemetry.send(@module, token, @time, {:error, %Response{response: "response"}})
    end

    test "when graphql request errors out", %{offline_token: token} do
      assert :ok == Telemetry.send(@module, token, @time, {:error, %Error{reason: "reason"}})
    end
  end
end
