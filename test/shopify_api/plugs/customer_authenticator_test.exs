defmodule ShopifyAPI.Plugs.CustomerAuthenticatorTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias ShopifyAPI.Plugs.CustomerAuthenticator
  alias ShopifyAPI.Security

  @secret "new_secret"

  describe "Valid Customer Auth" do
    test "assigns auth_payload to conn" do
      payload = auth_payload()
      signature = Security.base16_sha256_hmac(payload, @secret)

      conn = post(payload, signature)

      assert %{
               "email" => "email@example.com",
               "expiry" => _,
               "id" => "12345"
             } = conn.assigns.auth_payload
    end

    test "validates on second secret as well" do
      payload = auth_payload()
      signature = Security.base16_sha256_hmac(payload, "old_secret")

      conn = post(payload, signature)

      assert %{
               "email" => "email@example.com",
               "expiry" => _,
               "id" => "12345"
             } = conn.assigns.auth_payload
    end
  end

  describe "Invalid Customer Auth" do
    test "payload expired" do
      payload = DateTime.utc_now() |> add_seconds(-3600) |> auth_payload()
      signature = Security.base16_sha256_hmac(payload, "new_secret")

      conn = post(payload, signature)

      assert_unauthorized(conn, "auth_payload has expired")
    end

    test "malformed payload" do
      payload = "this payload is invalid"
      signature = Security.base16_sha256_hmac(payload, "new_secret")

      conn = post(payload, signature)

      assert_unauthorized(conn, "Could not parse auth_payload")
    end

    test "wrong secret" do
      payload = auth_payload()
      signature = Security.base16_sha256_hmac(payload, "wrong_secret")

      conn = post(payload, signature)

      assert_unauthorized(conn, "Authorization failed")
    end

    test "no payload" do
      payload = auth_payload()
      signature = Security.base16_sha256_hmac(payload, "new_secret")

      conn =
        :post
        |> conn("/", %{auth_signature: signature})
        |> CustomerAuthenticator.call([])

      assert_unauthorized(conn, "Authorization failed")
    end

    test "no signature" do
      payload = auth_payload()

      conn =
        :post
        |> conn("/", %{auth_payload: payload})
        |> CustomerAuthenticator.call([])

      assert_unauthorized(conn, "Authorization failed")
    end

    test "empty payload" do
      payload = ""
      signature = Security.base16_sha256_hmac(payload, "new_secret")

      conn = post(payload, signature)

      assert_unauthorized(conn, "Could not parse auth_payload")
    end

    test "empty expiry" do
      payload = ~s({"email":"email@example.com","id":"12345","expiry":""})
      signature = Security.base16_sha256_hmac(payload, "new_secret")

      conn = post(payload, signature)

      assert_unauthorized(conn, "A valid ISO8601 expiry must be included in auth_payload")
    end

    test "malformed expiry" do
      payload = ~s({"email":"email@example.com","id":"12345","expiry":"baddate"})
      signature = Security.base16_sha256_hmac(payload, "new_secret")

      conn = post(payload, signature)

      assert_unauthorized(conn, "A valid ISO8601 expiry must be included in auth_payload")
    end

    test "empty signature" do
      payload = auth_payload()
      signature = Security.base16_sha256_hmac(payload, "")

      conn = post(payload, signature)

      assert_unauthorized(conn, "Authorization failed")
    end
  end

  defp post(payload, signature) do
    :post
    |> conn("/", %{auth_payload: payload, auth_signature: signature})
    |> CustomerAuthenticator.call([])
  end

  defp assert_unauthorized(conn, message) do
    assert conn.status == 401
    assert conn.resp_body == message
    assert conn.assigns == %{}
  end

  defp auth_payload, do: DateTime.utc_now() |> add_seconds(360) |> auth_payload()

  defp auth_payload(expiry),
    do: ~s({"email":"email@example.com","id":"12345","expiry":"#{DateTime.to_iso8601(expiry)}"})

  defp add_seconds(date_time, seconds) do
    date_time
    |> DateTime.to_naive()
    |> NaiveDateTime.add(seconds)
    |> DateTime.from_naive!("Etc/UTC")
  end
end
