ExUnit.start()
{:ok, _} = ShopifyAPI.CacheSupervisor.start_link([])
Application.ensure_all_started(:bypass)
