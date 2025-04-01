defmodule ShopifyAPI.Factory do
  use ExMachina

  @shopify_app_name "testapp"
  @shopify_app_secret "new_secret"

  def shopify_gid(type), do: sequence(type, &"gid://shopify/#{type}/#{&1}")

  def shopify_int_id(type) do
    {:ok, shopify_id} = type |> shopify_gid() |> ShopifyAPI.ShopifyId.new(type)
    shopify_id.id
  end

  def shopify_app_name, do: @shopify_app_name
  def shopify_app_secret, do: @shopify_app_secret

  def myshopify_domain, do: Faker.Internet.slug() <> ".myshopify.com"

  def shop_factory do
    domain = myshopify_domain()
    %ShopifyAPI.Shop{domain: domain}
  end

  def app_factory do
    %ShopifyAPI.App{
      name: shopify_app_name(),
      client_id: "#{__MODULE__}.id",
      client_secret: shopify_app_secret()
    }
  end

  def auth_token_factory(params) do
    app_name = Map.get(params, :app_name, shopify_app_name())
    shop_name = Map.get(params, :shop_name, myshopify_domain())
    %ShopifyAPI.AuthToken{app_name: app_name, shop_name: shop_name, token: "test"}
  end

  def user_token_factory(params) do
    shop_name = Map.get(params, :shop_name, myshopify_domain())
    associated_user_id = String.to_integer(shopify_int_id(:user))

    %ShopifyAPI.UserToken{
      code: "ef91136f6d56c06c7339664dc51ee24f",
      app_name: shopify_app_name(),
      shop_name: shop_name,
      token: "shpua_8a2deac8ba1176ad2e3ec31652200d19",
      timestamp: DateTime.to_unix(DateTime.utc_now()),
      plus: false,
      scope: "write_customers,write_discounts,read_products",
      expires_in: 86_399,
      associated_user_scope: "write_customers,write_discounts,read_products",
      associated_user: %ShopifyAPI.AssociatedUser{
        id: associated_user_id,
        first_name: Faker.Person.first_name(),
        last_name: Faker.Person.last_name(),
        email: Faker.Internet.email(),
        email_verified: true,
        account_owner: true,
        locale: "en-CA",
        collaborator: false
      },
      associated_user_id: associated_user_id
    }
  end
end
