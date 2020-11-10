defmodule ShopifyAPI.GraphQL.Response do
  @moduledoc """
  The Response module handles parsing and unwrapping responses from Shopify's GraphQL Admin API.
  """

  alias ShopifyAPI.JSONSerializer
  alias ShopifyAPI.GraphQL.{JSONParseError, Response}

  @type t :: %ShopifyAPI.GraphQL.Response{
          response: map(),
          metadata: map(),
          status_code: integer(),
          headers: list()
        }

  defstruct response: %{},
            metadata: %{},
            status_code: nil,
            headers: []

  @doc """
  Parses a `%HTTPoison.Response{}` GraphQL response.

  Returns `{:ok, %Response{}}` if the API response was successful.
  If there were query errors, or a rate limit was exceeded, `{:error, %HTTPoison.Response{}}` is returned.
  If an error occurs while parsing the JSON response, `{:error, %JSONParseError{}}` is returned.
  If a request error occurs, `{:error, %HTTPoison.Error()}` is returned.
  """
  @spec handle({:ok, HTTPoison.Response.t()} | {:error, HTTPoison.Error.t()}) ::
          {:ok, t()} | {:error, HTTPoison.Response.t() | JSONParseError.t() | HTTPoison.Error.t()}
  def handle({:ok, response}) do
    case JSONSerializer.decode(response.body) do
      {:ok, body} -> build_response(%{response | body: body})
      {:error, error} -> handle_unparsable(response, error)
    end
  end

  def handle({:error, _} = response), do: response

  @doc false
  def build_response(%{body: %{"data" => nil}} = response), do: {:error, response}

  def build_response(%{body: %{"data" => data, "extensions" => extensions}} = response) do
    {
      :ok,
      %Response{
        status_code: response.status_code,
        response: data,
        metadata: extensions,
        headers: response.headers
      }
    }
  end

  def build_response(response), do: {:error, response}

  def handle_unparsable(response, error) do
    {
      :error,
      %JSONParseError{
        response: response,
        error: error
      }
    }
  end
end
