defmodule ShopifyAPI.ShopTest do
  use ExUnit.Case, async: true

  alias ShopifyAPI.Shop

  doctest ShopifyAPI.Shop

  describe "valid_domain?/1" do
    test "accepts a slug of lowercase letters, digits and hyphens" do
      for domain <- ["acme.myshopify.com", "a.myshopify.com", "0-acme-1.myshopify.com"] do
        assert Shop.valid_domain?(domain), domain
      end
    end

    test "rejects other hosts" do
      for domain <- [
            "evil.example.com",
            "myshopify.com",
            ".myshopify.com",
            "acme.myshopify.com.evil.example.com",
            "acmemyshopify.com",
            "acme.myshopify.comm",
            "acme.myshopify.co",
            "sub.acme.myshopify.com"
          ] do
        refute Shop.valid_domain?(domain), domain
      end
    end

    test "rejects anything that could change where a URI points" do
      for domain <- [
            "acme.myshopify.com:8080",
            "evil.example.com:443",
            "evil.example.com/.myshopify.com",
            "evil.example.com?.myshopify.com",
            "evil.example.com#.myshopify.com",
            "user@acme.myshopify.com",
            "evil.example.com@acme.myshopify.com",
            "https://acme.myshopify.com",
            "acme.myshopify.com/",
            "acme.myshopify.com\n",
            "evil.example.com\nacme.myshopify.com",
            " acme.myshopify.com"
          ] do
        refute Shop.valid_domain?(domain), inspect(domain)
      end
    end

    test "rejects malformed slugs" do
      for domain <- [
            "-acme.myshopify.com",
            "ACME.myshopify.com",
            "ac_me.myshopify.com",
            "acme.MYSHOPIFY.com"
          ] do
        refute Shop.valid_domain?(domain), domain
      end
    end

    test "rejects anything that is not a string" do
      for domain <- [nil, "", 1, %{"a" => "acme.myshopify.com"}, ["acme.myshopify.com"]] do
        refute Shop.valid_domain?(domain), inspect(domain)
      end
    end

    test "accepts a local server in the environments to_uri/1 allows a port in" do
      assert Shop.valid_domain?("localhost:4040")
      refute Shop.valid_domain?("localhost")
      refute Shop.valid_domain?("localhost:4040/path")
      refute Shop.valid_domain?("localhost:port")
    end
  end
end
