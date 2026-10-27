defmodule ShopifyAPI.AppServerTest do
  # Not async: the tests assert on captured logs, which would pick up output from tests running
  # alongside them.
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias ShopifyAPI.App
  alias ShopifyAPI.AppServer

  describe "set/1" do
    test "logs an error for an app with no usable secret" do
      for secret <- ["", "  ", nil] do
        app = %App{name: "blank-secret", client_id: "blank-secret-id", client_secret: secret}

        log = capture_log(fn -> assert AppServer.set(app) == :ok end)

        assert log =~ ~s(app "blank-secret" has no usable client secret), "for #{inspect(secret)}"
        assert log =~ "every session token, webhook and HMAC will be rejected"
        assert AppServer.get("blank-secret") == {:ok, app}
      end
    end

    test "logs an error for a blank client secret that a secondary secret still verifies for" do
      app = %App{
        name: "blank-primary",
        client_id: "blank-primary-id",
        client_secret: "",
        client_secret_secondary: "old"
      }

      log = capture_log(fn -> assert AppServer.set(app) == :ok end)

      assert log =~ ~s(app "blank-primary" has a blank client_secret)
      assert log =~ "signatures verify against client_secret_secondary alone"
      refute log =~ "will be rejected"
    end

    test "logs nothing for a blank secondary secret" do
      app = %App{
        name: "no-rotation",
        client_id: "no-rotation-id",
        client_secret: "current",
        client_secret_secondary: ""
      }

      assert capture_log(fn -> AppServer.set(app) end) == ""
    end
  end
end
