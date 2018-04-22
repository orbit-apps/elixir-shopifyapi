defmodule GraphQL.Config.Resolver do
  def all_shops(_root, _args, _info) do
    shops = Enum.map(ShopifyApi.ShopServer.all(), fn x -> elem(x, 1) end)
    {:ok, shops}
  end

  def update_shop(_root, args, _info) do
    with :ok <- ShopifyApi.ShopServer.set(args),
         {:ok, shop} <- ShopifyApi.ShopServer.get(args.domain) do
      {:ok, shop}
    else
      _ ->
        {:error, "could not create shop"}
    end
  end

  def all_apps(_root, _args, _info) do
    apps = Enum.map(ShopifyApi.AppServer.all(), fn x -> elem(x, 1) end)
    {:ok, apps}
  end

  def tokens_for_app(app, _, _) do
    tokens = case ShopifyApi.AuthTokenServer.get_for_app(app.name) do
      nil -> []
      results -> results
    end
    {:ok, tokens}
  end

  def update_app(_root, args, _info) do
    with :ok <- ShopifyApi.AppServer.set(args.name, args),
         {:ok, app} <- ShopifyApi.AppServer.get(args.name) do
      {:ok, app}
    else
      _ ->
        {:error, "could not create shop"}
    end
  end

  def all_auth_tokens(_root, _args, _info) do
    tokens = Enum.map(ShopifyApi.AuthTokenServer.all(), fn x -> elem(x, 1) end)
    {:ok, tokens}
  end
end
