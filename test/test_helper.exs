ExUnit.start()
{:ok, _} = ShopifyAPI.Supervisor.start_link([])
Application.ensure_all_started(:bypass)
