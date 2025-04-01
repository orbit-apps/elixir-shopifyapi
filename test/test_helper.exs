ExUnit.start()
{:ok, _} = ShopifyAPI.Supervisor.start_link([])
{:ok, _} = Application.ensure_all_started(:bypass)
{:ok, _} = Application.ensure_all_started(:ex_machina)
