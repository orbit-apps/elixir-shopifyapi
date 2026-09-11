defmodule ShopifyAPI.AuthTokenTest do
  use ExUnit.Case, async: true

  alias ShopifyAPI.App
  alias ShopifyAPI.AuthToken

  doctest ShopifyAPI.AuthToken
  # ShopifyAPI.Test builds AuthToken states, so its builder doctests run here.
  doctest ShopifyAPI.Test

  @app %App{name: "my-app"}

  # A complete expiring pair. validate_pair/1 compares the two expiries with each other, never
  # with the clock, so fixed instants keep its examples exact.
  @pair %AuthToken{
    token_expires_at: ~U[2026-09-11 13:00:00Z],
    refresh_token: "shprt_xyz",
    refresh_token_expires_at: ~U[2026-12-10 13:00:00Z]
  }

  describe "from_auth_request/4" do
    test "derives both expiries from the response durations" do
      attrs = %{
        "access_token" => "shpat_abc",
        "expires_in" => 3600,
        "refresh_token" => "shprt_xyz",
        "refresh_token_expires_in" => 7_775_999
      }

      before = DateTime.utc_now()
      token = AuthToken.from_auth_request(@app, "shop.myshopify.com", attrs)

      assert_in_delta DateTime.diff(token.token_expires_at, before), 3600, 2
      assert_in_delta DateTime.diff(token.refresh_token_expires_at, before), 7_775_999, 2
    end

    test "leaves the expiring fields nil for a permanent token" do
      token =
        AuthToken.from_auth_request(@app, "shop.myshopify.com", %{"access_token" => "shpat"})

      assert token.refresh_token == nil
      assert token.token_expires_at == nil
      assert token.refresh_token_expires_at == nil
    end

    test "writes a replayed response's partly-spent countdown honestly" do
      # A replay returns the original pair with its countdown already running down, so a
      # short expires_in must be taken at face value rather than treated as a fresh hour.
      attrs = %{
        "access_token" => "shpat_abc",
        "expires_in" => 12,
        "refresh_token" => "shprt_xyz",
        "refresh_token_expires_in" => 7_775_999
      }

      before = DateTime.utc_now()
      token = AuthToken.from_auth_request(@app, "shop.myshopify.com", attrs)

      assert_in_delta DateTime.diff(token.token_expires_at, before), 12, 2
    end
  end

  describe "validate_pair/1" do
    test "accepts a permanent token, which carries none of the expiring fields" do
      assert :ok = AuthToken.validate_pair(%AuthToken{})
    end

    test "accepts a complete pair whose refresh token outlives its access token" do
      assert :ok = AuthToken.validate_pair(@pair)
    end

    for {label, access_token} <- [missing: nil, "not a string": 12_345] do
      test "rejects a permanent token whose access token is #{label}" do
        token = %AuthToken{token: unquote(access_token)}

        assert {:error, :incomplete_pair} = AuthToken.validate_pair(token)
      end

      test "rejects an expiring token whose access token is #{label}" do
        token = %{@pair | token: unquote(access_token)}

        assert {:error, :incomplete_pair} = AuthToken.validate_pair(token)
      end
    end

    # Every mix of set and unset fields short of all three or none.
    for present <- [
          [:token_expires_at],
          [:refresh_token],
          [:refresh_token_expires_at],
          [:token_expires_at, :refresh_token],
          [:token_expires_at, :refresh_token_expires_at],
          [:refresh_token, :refresh_token_expires_at]
        ] do
      test "rejects a token with only #{Enum.join(present, " and ")} set" do
        token = struct!(AuthToken, Map.take(Map.from_struct(@pair), unquote(present)))

        assert {:error, :incomplete_pair} = AuthToken.validate_pair(token)
      end
    end

    test "rejects a refresh token that is not a string" do
      token = %{@pair | refresh_token: 12_345}

      assert {:error, :incomplete_pair} = AuthToken.validate_pair(token)
    end

    test "rejects expiries that are not DateTimes" do
      token = %{@pair | token_expires_at: 3600, refresh_token_expires_at: 7_775_999}

      assert {:error, :incomplete_pair} = AuthToken.validate_pair(token)
    end

    test "rejects a refresh token that expires before its access token" do
      token = %{@pair | refresh_token_expires_at: ~U[2026-09-11 12:59:59Z]}

      assert {:error, :refresh_token_expires_first} = AuthToken.validate_pair(token)
    end
  end

  describe "refresh_outlives_access?/1" do
    test "is true when the refresh token expires after the access token" do
      assert AuthToken.refresh_outlives_access?(@pair)
    end

    test "is false when both expire at the same instant" do
      token = %{@pair | refresh_token_expires_at: @pair.token_expires_at}

      refute AuthToken.refresh_outlives_access?(token)
    end

    test "is false when the refresh token expires first" do
      token = %{@pair | refresh_token_expires_at: ~U[2026-09-11 12:59:59Z]}

      refute AuthToken.refresh_outlives_access?(token)
    end

    test "is false for a permanent token" do
      refute AuthToken.refresh_outlives_access?(%AuthToken{})
    end

    test "is false without an access token expiry" do
      refute AuthToken.refresh_outlives_access?(%{@pair | token_expires_at: nil})
    end

    test "is false without a refresh token expiry" do
      refute AuthToken.refresh_outlives_access?(%{@pair | refresh_token_expires_at: nil})
    end
  end

  describe "serialization" do
    test "round-trips the expiring fields through Jason" do
      attrs = %{
        "access_token" => "shpat_abc",
        "expires_in" => 3600,
        "refresh_token" => "shprt_xyz",
        "refresh_token_expires_in" => 7_775_999
      }

      encoded =
        @app
        |> AuthToken.from_auth_request("shop.myshopify.com", attrs)
        |> Jason.encode!()
        |> Jason.decode!()

      assert encoded["refresh_token"] == "shprt_xyz"
      assert encoded["token_expires_at"]
      assert encoded["refresh_token_expires_at"]
    end

    test "keeps secrets out of inspect output" do
      attrs = %{
        "access_token" => "shpat_secret",
        "refresh_token" => "shprt_secret",
        "expires_in" => 3600
      }

      inspected =
        @app
        |> AuthToken.from_auth_request("shop.myshopify.com", "auth-code-secret", attrs)
        |> inspect()

      refute inspected =~ "shpat_secret"
      refute inspected =~ "shprt_secret"
      refute inspected =~ "auth-code-secret"
      assert inspected =~ "shop.myshopify.com"
    end
  end
end
