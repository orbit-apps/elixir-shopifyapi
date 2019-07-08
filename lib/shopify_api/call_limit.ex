defmodule ShopifyAPI.CallLimit do
  @moduledoc """
  Responsible for handling ShopifyAPI call limits in a HTTPoison.Response
  """
  @shopify_call_limit_header "X-Shopify-Shop-Api-Call-Limit"
  @shopify_retry_after_header "Retry-After"
  @over_limit_status_code 429
  # API Overlimit error code
  @spec limit_header_or_status_code(any) :: nil | :over_limit
  def limit_header_or_status_code(%{status_code: @over_limit_status_code()}),
    do: :over_limit

  def limit_header_or_status_code(%{headers: headers}),
    do: get_header(headers, @shopify_call_limit_header)

  def limit_header_or_status_code(_conn), do: nil

  def get_api_remaining_calls(nil), do: 0

  def get_api_remaining_calls(:over_limit), do: 0

  def get_api_remaining_calls(header_value) do
    # comes in the form "1/40": 1 taken of 40
    header_value
    |> String.split("/")
    |> Enum.map(&String.to_integer/1)
    |> calculate_available
  end

  def get_retry_after_header(%{headers: headers}) do
    get_header(headers, @shopify_retry_after_header, "2.0")
  end

  def get_retry_after_milliseconds(header_value) do
    {seconds, remainder} = Integer.parse(header_value)

    {milliseconds, ""} =
      remainder
      |> String.replace_prefix(".", "")
      |> String.pad_trailing(3, "0")
      |> Integer.parse()

    seconds * 1000 + milliseconds
  end

  def get_header(headers, header_name, default \\ nil) do
    Enum.find_value(
      headers,
      default,
      fn
        {^header_name, value} -> value
        _ -> nil
      end
    )
  end

  defp calculate_available([used, total]), do: total - used
end
