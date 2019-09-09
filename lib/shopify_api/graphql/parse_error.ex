defmodule ShopifyAPI.GraphQL.JSONParseError do
  @moduledoc """
  Struct representation of a JSON parse error.
  """

  alias HTTPoison.Response

  @type t :: %ShopifyAPI.GraphQL.JSONParseError{
          error: map(),
          response: Response.t()
        }

  defstruct response: %Response{},
            error: nil
end
