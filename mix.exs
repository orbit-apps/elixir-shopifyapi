defmodule Plug.ShopifyApi.MixProject do
  use Mix.Project

  @version "0.1.2"

  def project do
    [
      app: :shopify_api,
      version: @version,
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [plt_add_deps: :transitive],
      test_coverage: [tool: ExCoveralls]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {ShopifyApi.Application, []},
      extra_applications: [
        :httpoison,
        :logger,
        :poison
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:absinthe_plug, "~> 1.4.0"},
      {:absinthe, "~> 1.4.0"},
      {:bypass, "~> 0.8", only: :test},
      {:credo, "~> 0.3", only: [:dev, :test]},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:excoveralls, only: [:dev, :test]},
      {:httpoison, "~> 1.0"},
      {:plug, "~> 1.0"},
      {:poison, "~> 3.1"}
    ]
  end
end
