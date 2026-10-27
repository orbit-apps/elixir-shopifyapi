defmodule ShopifyAPI.JWTSessionTokenTest do
  use ExUnit.Case, async: true

  alias ShopifyAPI.App
  alias ShopifyAPI.JWTSessionToken

  @payload %{"aud" => "client-id", "dest" => "https://shop.myshopify.com", "sub" => "1"}

  defp sign(secret) do
    {_, token} =
      secret
      |> JOSE.JWK.from_oct()
      |> JOSE.JWT.sign(%{"alg" => "HS256"}, @payload)
      |> JOSE.JWS.compact()

    token
  end

  describe "verify/2 with an app" do
    setup do
      [app: %App{client_secret: "current", client_secret_secondary: "old"}]
    end

    test "accepts a token signed with the current secret", %{app: app} do
      assert {true, %JOSE.JWT{fields: @payload}, _jws} =
               JWTSessionToken.verify(sign("current"), app)
    end

    test "accepts a token signed with the secondary secret", %{app: app} do
      assert {true, %JOSE.JWT{fields: @payload}, _jws} = JWTSessionToken.verify(sign("old"), app)
    end

    test "rejects a token signed with any other secret", %{app: app} do
      assert {false, _jwt, _jws} = JWTSessionToken.verify(sign("other"), app)
    end

    test "rejects a token that isn't a JWT", %{app: app} do
      assert {:error, _} = JWTSessionToken.verify("not.a.jwt", app)
    end

    test "accepts the current secret alone outside a rotation" do
      app = %App{client_secret: "current"}

      assert {true, _jwt, _jws} = JWTSessionToken.verify(sign("current"), app)
      assert {false, _jwt, _jws} = JWTSessionToken.verify(sign("old"), app)
    end

    test "rejects a token signed with a blank key when the secondary is blank" do
      app = %App{client_secret: "current", client_secret_secondary: ""}

      assert {false, _jwt, _jws} = JWTSessionToken.verify(sign(""), app)
    end

    test "rejects every token when the app has no usable secret" do
      app = %App{client_secret: ""}

      assert JWTSessionToken.verify(sign(""), app) == {:error, :no_usable_secret}
    end
  end

  describe "verify/2 with a secret" do
    test "accepts a token signed with that secret" do
      assert {true, %JOSE.JWT{fields: @payload}, _jws} =
               JWTSessionToken.verify(sign("current"), "current")
    end

    test "rejects a token signed with another secret" do
      assert {false, _jwt, _jws} = JWTSessionToken.verify(sign("other"), "current")
    end

    test "rejects every token when the secret is blank" do
      for secret <- ["", "  "] do
        assert JWTSessionToken.verify(sign(secret), secret) == {:error, :no_usable_secret}
      end
    end
  end
end
