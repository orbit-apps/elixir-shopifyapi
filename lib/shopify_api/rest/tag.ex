defmodule ShopifyAPI.REST.Tag do
  @moduledoc """
  Helpers methods for dealing with Shopify Tags. Tags in Shopify are just a string field with
  comma separated values, since tags are more accessible then Metafields we have included the
  ability to encode key/value pairs in the tag.

  ## Examples

      iex> "foo, bar" |> Tag.decode()
      ["foo", "bar"]

      iex> ["foo", "bar"] |> Tag.encode()
      "foo, bar"

      iex> "foo, bar::baz" |> Tag.decode("::")
      ["foo", {"bar", "baz"}]

      iex> ["foo", {"bar", "baz"}] |> Tag.encode("::")
      "foo, bar::baz"
  """
  @spec decode(String.t()) :: list
  def decode(string) when is_binary(string) do
    string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
  end

  def decode(tags, _) when tags == "", do: []

  @spec decode(String.t(), String.t()) :: list({String.t(), String.t()})
  def decode(tags, tag_separator) when is_binary(tags),
    do: tags |> decode() |> decode(tag_separator)

  @spec decode(list(String.t()), String.t()) :: list({String.t(), String.t()})
  def decode(tags, tag_separator) when is_list(tags) do
    tags
    |> Enum.map(&String.split(&1, tag_separator, parts: 2))
    |> Enum.map(&decode_split/1)
  end

  @spec encode(list(String.t())) :: String.t()
  def encode(tags) when is_list(tags), do: Enum.join(tags, ", ")

  @spec encode(list({String.t(), String.t()}), String.t()) :: String.t()
  def encode(tags, tag_separator) when is_list(tags) do
    tags
    |> Enum.map(&apply_separator(&1, tag_separator))
    |> encode()
  end

  def value({_, value}), do: value
  def value(value), do: value

  defp apply_separator(value, _separator) when is_binary(value), do: value
  defp apply_separator({value}, _separator), do: value

  defp apply_separator(tag, separator) when is_tuple(tag),
    do: tag |> Tuple.to_list() |> Enum.join(separator)

  defp decode_split(tag) when length(tag) == 1, do: List.first(tag)
  defp decode_split(tag), do: List.to_tuple(tag)
end
