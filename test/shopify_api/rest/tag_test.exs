defmodule ShopifyAPI.REST.TagTest do
  use ExUnit.Case
  use ExUnitProperties

  alias ShopifyAPI.REST.Tag

  describe "Tags.encode and decode" do
    property "single tag test" do
      check all(
              tag_name <- string(:alphanumeric),
              tag_name != "",
              tag_value <- string(:alphanumeric),
              tag_value != ""
            ) do
        assert [{tag_name, tag_value}] ==
                 [{tag_name, tag_value}] |> Tag.encode("::") |> Tag.decode("::")
      end
    end

    property "tags collection" do
      check all(tags <- list_of({string(:alphanumeric), string(:alphanumeric)})) do
        assert tags == tags |> Tag.encode("::") |> Tag.decode("::")
      end
    end

    property "mixed tags collection" do
      check all(
              complex_tags <- list_of({string(:alphanumeric), string(:alphanumeric)}),
              complex_tags != [],
              simple_tags <- list_of(string(:alphanumeric))
            ) do
        tags = complex_tags ++ simple_tags
        assert tags == tags |> Tag.encode("::") |> Tag.decode("::")
      end
    end

    property "simple tags" do
      check all(tags <- list_of(string(:alphanumeric), min_length: 1)) do
        assert tags == tags |> Tag.encode() |> Tag.decode()
      end
    end
  end
end
