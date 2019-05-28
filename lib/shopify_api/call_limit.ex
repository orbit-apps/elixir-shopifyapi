defmodule ShopifyAPI.CallLimit do
  @moduledoc """
  Responsible for handling ShopifyAPI call limits in a HTTPoison.Response
  """
  @shopify_call_limit_header "X-Shopify-Shop-Api-Call-Limit"
  @over_limit_status_code 429
  # API Overlimit error code
  def limit_header_or_status_code(%{status_code: @over_limit_status_code()}),
    do: :over_limit

  def limit_header_or_status_code(%{headers: headers}),
    do: Enum.find(headers, fn header -> elem(header, 0) == @shopify_call_limit_header end)

  def limit_header_or_status_code(_conn), do: nil

  def get_api_call_limit(nil), do: nil

  def get_api_call_limit(:over_limit), do: 0

  def get_api_call_limit(header) do
    # comes in the form "1/40": 1 taken of 40
    header
    |> get_value_from_header
    |> String.split("/")
    |> Enum.map(&String.to_integer/1)
    |> calculate_available
  end

  defp get_value_from_header({_, value}), do: value

  defp calculate_available([used, total]), do: total - used
end
