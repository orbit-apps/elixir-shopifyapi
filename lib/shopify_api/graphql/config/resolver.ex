defmodule ShopifyAPI.GraphQL.Config.Resolver do
  alias ShopifyAPI.{AppServer, AuthTokenServer, ShopServer}

  def all_shops(_root, _args, _info) do
    shops = Enum.map(ShopServer.all(), fn x -> elem(x, 1) end)
    {:ok, shops}
  end

  def update_shop(_root, args, _info) do
    with :ok <- ShopServer.set(args),
         {:ok, shop} <- ShopServer.get(args.domain) do
      {:ok, shop}
    else
      _ ->
        {:error, "could not create shop"}
    end
  end

  def all_apps(_root, _args, _info) do
    apps = Enum.map(AppServer.all(), fn x -> elem(x, 1) end)
    {:ok, apps}
  end

  def tokens_for_app(app, _, _) do
    tokens =
      case AuthTokenServer.get_for_app(app.name) do
        nil -> []
        results -> results
      end

    {:ok, tokens}
  end

  def update_app(_root, args, _info) do
    with :ok <- AppServer.set(args.name, args),
         {:ok, app} <- AppServer.get(args.name) do
      {:ok, app}
    else
      _ ->
        {:error, "could not create shop"}
    end
  end

  def all_auth_tokens(_root, _args, _info) do
    tokens = Enum.map(AuthTokenServer.all(), fn x -> elem(x, 1) end)
    {:ok, tokens}
  end

  def update_auth_token(_root, %{shop_name: shop, app_name: app} = args, _info) do
    with :ok <- AuthTokenServer.set(args),
         {:ok, token} <- AuthTokenServer.get(shop, app) do
      {:ok, token}
    else
      _ ->
        {:error, "could not create shop"}
    end
  end
end
