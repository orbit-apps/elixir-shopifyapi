defmodule ShopifyAPI.RESTTest do
  use ExUnit.Case

  import Bypass, only: [expect_once: 4]

  alias ShopifyAPI.AuthToken
  alias ShopifyAPI.REST
  alias ShopifyAPI.REST.Request

  defmodule MockAPIResponses do
    import Plug.Conn

    # Used to test that the Shopify auth header is set
    def assert_auth_header_set(%{req_headers: req_headers} = conn) do
      headers = Enum.into(req_headers, %{})
      assert headers["x-shopify-access-token"] == "token"
      resp(conn, 200, "{}")
    end

    def success(status \\ 200, body \\ "{}"),
      do: generate_response(status, body)

    def failure(status \\ 500, body \\ "{}"),
      do: generate_response(status, body)

    defp generate_response(status, body) when is_integer(status) and is_binary(body) do
      fn conn -> resp(conn, status, body) end
    end
  end

  setup do
    bypass = Bypass.open()
    token = %AuthToken{token: "token", shop_name: "localhost:#{bypass.port}"}
    {:ok, %{token: token, bypass: bypass}}
  end

  test "adds API auth header to outgoing requests", %{bypass: bypass, token: token} do
    expect_once(
      bypass,
      "GET",
      "/admin/api/#{Request.version()}/example",
      &MockAPIResponses.assert_auth_header_set/1
    )

    assert {:ok, _} = REST.get(token, "example")
  end

  describe "GET" do
    test "returns ok when returned status code is 200", %{bypass: bypass, token: token} do
      expect_once(
        bypass,
        "GET",
        "/admin/api/#{Request.version()}/example",
        MockAPIResponses.success()
      )

      assert {:ok, _} = REST.get(token, "example")
    end

    test "returns errors from API on non-200 responses", %{bypass: bypass, token: token} do
      expect_once(
        bypass,
        "GET",
        "/admin/api/#{Request.version()}/example",
        MockAPIResponses.failure()
      )

      assert {:error, %{status_code: 500}} = REST.get(token, "example")
    end
  end

  describe "POST" do
    test "returns ok when returned status code is 201", %{bypass: bypass, token: token} do
      expect_once(
        bypass,
        "POST",
        "/admin/api/#{Request.version()}/example",
        MockAPIResponses.success(201)
      )

      assert {:ok, _} = REST.post(token, "example", %{})
    end

    test "returns errors from API on non-200 responses", %{bypass: bypass, token: token} do
      expect_once(
        bypass,
        "POST",
        "/admin/api/#{Request.version()}/example",
        MockAPIResponses.failure(422)
      )

      assert {:error, %{status_code: 422}} = REST.post(token, "example", "")
    end
  end

  describe "DELETE" do
    test "is successful when API returns a 2XX status", %{bypass: bypass, token: token} do
      expect_once(
        bypass,
        "DELETE",
        "/admin/api/#{Request.version()}/example",
        MockAPIResponses.success(200)
      )

      assert {:ok, _} = REST.delete(token, "example")
    end

    test "returns errors from API on non-200 responses", %{bypass: bypass, token: token} do
      expect_once(
        bypass,
        "DELETE",
        "/admin/api/#{Request.version()}/example",
        MockAPIResponses.failure(404)
      )

      assert {:error, %{status_code: 404}} = REST.delete(token, "example")
    end
  end

  describe "extract_results_and_next_link" do
    test "returns next link if found" do
      headers = [{"Link", "<https://example.com?page=2>; rel=\"next\""}]
      response = %HTTPoison.Response{body: "", headers: headers}
      {_, next_link} = Request.extract_results_and_next_link(response)
      assert next_link == "https://example.com?page=2"
    end

    test "returns nil if next link not found" do
      headers = [{"Link", "<https://example.com?page=1>; rel=\"prev\""}]
      response = %HTTPoison.Response{body: "", headers: headers}
      {_, next_link} = Request.extract_results_and_next_link(response)
      assert next_link == nil
    end

    test "returns nil if headers are empty" do
      response = %HTTPoison.Response{body: "", headers: []}
      {_, next_link} = Request.extract_results_and_next_link(response)
      assert next_link == nil
    end

    test "returns nil if 'Link' header is missing" do
      headers = [{"Content-Type", "application/json"}]
      response = %HTTPoison.Response{body: "", headers: headers}
      {_, next_link} = Request.extract_results_and_next_link(response)
      assert next_link == nil
    end
  end
end
