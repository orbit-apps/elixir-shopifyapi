defmodule ShopifyAPI.SecurityTest do
  use ExUnit.Case, async: true

  alias ShopifyAPI.App
  alias ShopifyAPI.Security

  doctest ShopifyAPI.Security

  @rotating_app %App{client_secret: "current", client_secret_secondary: "old"}

  describe "valid_params_hmac?/2" do
    @params %{"code" => "abc", "shop" => "shop.myshopify.com", "timestamp" => "1234"}

    defp signed(params, secret) do
      message = "code=abc&shop=shop.myshopify.com&timestamp=1234"
      Map.put(params, "hmac", Security.base16_sha256_hmac(message, secret))
    end

    test "accepts params signed with the current secret" do
      assert Security.valid_params_hmac?(@rotating_app, signed(@params, "current"))
    end

    test "accepts params signed with the secondary secret" do
      assert Security.valid_params_hmac?(@rotating_app, signed(@params, "old"))
    end

    test "leaves the signature parameter out of the signed string" do
      params = @params |> Map.put("signature", "anything") |> signed("current")
      assert Security.valid_params_hmac?(@rotating_app, params)
    end

    test "rejects params signed with any other secret" do
      refute Security.valid_params_hmac?(@rotating_app, signed(@params, "other"))
    end

    test "rejects params whose values were changed after signing" do
      params = %{signed(@params, "current") | "shop" => "evil.myshopify.com"}
      refute Security.valid_params_hmac?(@rotating_app, params)
    end

    test "rejects params without an hmac" do
      refute Security.valid_params_hmac?(@rotating_app, @params)
      refute Security.valid_params_hmac?(@rotating_app, Map.put(@params, "hmac", nil))
    end

    test "rejects params signed with a blank key when the secondary is blank" do
      app = %App{client_secret: "current", client_secret_secondary: ""}
      refute Security.valid_params_hmac?(app, signed(@params, ""))
    end

    test "rejects every request when the app has no usable secret" do
      refute Security.valid_params_hmac?(%App{client_secret: ""}, signed(@params, ""))
    end
  end

  describe "valid_body_hmac?/3" do
    @body ~s({"id":1234})

    test "accepts a body signed with the current secret" do
      hmac = Security.base64_sha256_hmac(@body, "current")
      assert Security.valid_body_hmac?(@rotating_app, @body, hmac)
    end

    test "accepts a body signed with the secondary secret" do
      hmac = Security.base64_sha256_hmac(@body, "old")
      assert Security.valid_body_hmac?(@rotating_app, @body, hmac)
    end

    test "rejects a body signed with any other secret" do
      hmac = Security.base64_sha256_hmac(@body, "other")
      refute Security.valid_body_hmac?(@rotating_app, @body, hmac)
    end

    test "rejects a body changed after signing" do
      hmac = Security.base64_sha256_hmac(@body, "current")
      refute Security.valid_body_hmac?(@rotating_app, ~s({"id":4321}), hmac)
    end

    test "rejects a body signed with a blank key when the secondary is blank" do
      app = %App{client_secret: "current", client_secret_secondary: ""}
      refute Security.valid_body_hmac?(app, @body, Security.base64_sha256_hmac(@body, ""))
    end

    test "rejects every body when the app has no usable secret" do
      app = %App{client_secret: ""}
      refute Security.valid_body_hmac?(app, @body, Security.base64_sha256_hmac(@body, ""))
    end
  end
end
