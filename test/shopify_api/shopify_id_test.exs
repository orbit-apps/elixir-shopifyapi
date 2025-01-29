defmodule ShopifyAPI.ShopifyIdTest do
  use ExUnit.Case, async: true

  alias ShopifyAPI.ShopifyId

  @id_types [
    :collection,
    :customer,
    :delivery_carrier_service,
    :delivery_location_group,
    :delivery_profile,
    :delivery_zone,
    :draft_order,
    :draft_order_line_item,
    :email_template,
    :fulfillment,
    :fulfillment_event,
    :fulfillment_service,
    :inventory_item,
    :line_item,
    :location,
    :marketing_event,
    :media_image,
    :metafield,
    :online_store_article,
    :online_store_blog,
    :online_store_page,
    :order,
    :order_transaction,
    :product,
    :product_image,
    :product_variant,
    :refund,
    :shop,
    :staff_member,
    :theme
  ]

  @id Enum.random(1_000_000_000_000..9_999_999_999_999)
  @sid Integer.to_string(@id)
  @id_type Enum.random(@id_types)
  @id_type_string ShopifyId.deatomize_type(@id_type)
  @struct_id ShopifyId.new!(@sid, @id_type)
  @string_id "gid://shopify/#{@id_type_string}/#{@sid}"

  describe "new/2" do
    test "creates a ShopifyId" do
      assert {:ok, %ShopifyId{object_type: @id_type, id: @sid}} = ShopifyId.new(@id, @id_type)
      assert {:ok, %ShopifyId{object_type: @id_type, id: @sid}} = ShopifyId.new(@sid, @id_type)

      assert {:ok, %ShopifyId{object_type: @id_type, id: @sid}} =
               ShopifyId.new(@string_id, @id_type)
    end

    test "does NOT create a ShopifyId with mismatched type" do
      gid = "gid://shopify/Order/12345"

      assert :error = ShopifyId.new(gid, :customer)
    end
  end

  describe "new!/2" do
    test "creates a ShopifyId" do
      assert %ShopifyId{object_type: @id_type, id: @sid} = ShopifyId.new!(@id, @id_type)
      assert %ShopifyId{object_type: @id_type, id: @sid} = ShopifyId.new!(@sid, @id_type)
      assert %ShopifyId{object_type: @id_type, id: @sid} = ShopifyId.new!(@string_id, @id_type)
    end

    test "does NOT create a ShopifyId with mismatched type" do
      gid = "gid://shopify/Order/12345"

      assert_raise ArgumentError, fn ->
        ShopifyId.new!(gid, :customer)
      end
    end
  end

  describe "stringify/1" do
    test "returns a string representation of a ShopifyId" do
      assert ShopifyId.stringify(@struct_id) == @string_id
    end
  end

  describe "Jason" do
    test "ShopifyId serializes to json" do
      assert Jason.encode!(%{customer_id: @struct_id}) ==
               ~s({"customer_id":"#{@string_id}"})
    end
  end

  defmodule Schema do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "" do
      field(:order_id, ShopifyId, type: :order)
    end
  end
end
