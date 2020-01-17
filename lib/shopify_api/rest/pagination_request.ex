defmodule ShopifyAPI.REST.PaginatedRequest do
  def product_stream(domain, api_key) do
    headers = headers(api_key)

    Stream.resource(
      fn -> endpoint(domain) end,
      fn url ->
        {:ok, response} = HTTPoison.get(url, headers)
        results = extract_results!(response)

        case extract_next_link(response) do
          {:ok, next_url} -> {results, next_url}
          :error -> {:halt, results}
        end
      end,
      fn _ -> :ok end
    )
  end

  def headers(api_key) do
    [
      {"Content-Type", "application/json"},
      {"X-Shopify-Access-Token", api_key}
    ]
  end

  defp endpoint(domain) do
    "https://#{domain}/admin/api/2020-01/orders.json?limit=50"
  end

  defp extract_results!(%{body: body}) do
    {:ok, %{orders: results}} = Jason.decode(body, keys: :atoms)
    results
  end

  defp extract_next_link(%{headers: headers}) do
    headers
    |> Enum.find_value(fn {name, value} -> name == "Link" and value end)
    |> String.split(", ")
    |> Enum.map(&String.split(&1, "; "))
    |> Map.new(fn [url, rel] ->
      [_, rel] = Regex.run(~r/rel="(.*)"/, rel)
      [_, url] = Regex.run(~r/<(.*)>/, url)

      {rel, url}
    end)
    |> Map.fetch("next")
  end
end
