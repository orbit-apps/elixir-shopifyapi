defmodule GraphQL.Config.Schema do
  use Absinthe.Schema

  object :shop do
    field(:domain, :string)
  end

  object :app do
    field(:name, :string)
    field(:client_id, :string)
    field(:client_secret, :string)
    field(:scope, :string)
    field(:auth_redirect_uri, :string)
    field(:nonce, :string)
    field(:auth_tokens, list_of(:auth_token)) do
      resolve(&GraphQL.Config.Resolver.tokens_for_app/3)
    end
  end

  object :auth_token do
    field(:code, :string)
    field(:token, :string)
    field(:shop, :string)
    field(:timestamp, :integer)
    field(:shop)
  end

  query do
    field :all_shops, non_null(list_of(non_null(:shop))) do
      resolve(&GraphQL.Config.Resolver.all_shops/3)
    end

    field :all_apps, non_null(list_of(non_null(:app))) do
      resolve(&GraphQL.Config.Resolver.all_apps/3)
    end

    field :all_auth_tokens, non_null(list_of(non_null(:auth_token))) do
      resolve(&GraphQL.Config.Resolver.all_auth_tokens/3)
    end
  end

  mutation do
    field :update_shop, :shop do
      arg(:domain, non_null(:string))
      resolve(&GraphQL.Config.Resolver.update_shop/3)
    end

    field :update_app, :app do
      arg(:name, non_null(:string))
      arg(:client_id, non_null(:string))
      arg(:client_secret, non_null(:string))
      arg(:scope, non_null(:string))
      arg(:auth_redirect_uri, non_null(:string))
      arg(:nonce, non_null(:string))
      resolve(&GraphQL.Config.Resolver.update_app/3)
    end
  end
end
