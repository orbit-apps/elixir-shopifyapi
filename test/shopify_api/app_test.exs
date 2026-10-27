defmodule ShopifyAPI.AppTest do
  use ExUnit.Case, async: true

  alias ShopifyAPI.App

  doctest ShopifyAPI.App

  describe "verification_secrets/1" do
    test "returns the current secret alone outside a rotation" do
      assert App.verification_secrets(%App{client_secret: "current"}) == ["current"]
    end

    test "returns the current secret before the secondary" do
      app = %App{client_secret: "current", client_secret_secondary: "old"}
      assert App.verification_secrets(app) == ["current", "old"]
    end

    test "leaves out a blank or non-string secondary" do
      for secondary <- [nil, "", "  ", "\n", :old, 123] do
        app = %App{client_secret: "current", client_secret_secondary: secondary}
        assert App.verification_secrets(app) == ["current"], "for #{inspect(secondary)}"
      end
    end

    test "leaves out a blank or non-string current secret" do
      for current <- [nil, "", "  ", "\n", :current] do
        app = %App{client_secret: current, client_secret_secondary: "new"}
        assert App.verification_secrets(app) == ["new"], "for #{inspect(current)}"
      end
    end

    test "returns no secrets when both are blank" do
      assert App.verification_secrets(%App{}) == []
      assert App.verification_secrets(%App{client_secret: "", client_secret_secondary: " "}) == []
    end
  end
end
