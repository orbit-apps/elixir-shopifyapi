defmodule Plug.ShopifyAPI.MixProject do
  use Mix.Project

  @version "0.12.5"

  def project do
    [
      app: :shopify_api,
      version: @version,
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [
        plt_add_apps: [:mix, :ex_unit],
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
      ],
      package: package(),

      # Ex_Doc configuration
      name: "Shopify API",
      source_url: "https://github.com/pixelunion/elixir-shopifyapi",
      docs: [
        main: "ShopifyAPI.App",
        extras: ["README.md"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {ShopifyAPI.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Dev and Test
      {:bypass, "~> 2.1", only: :test},
      {:credo, "~> 1.0", only: [:dev, :test]},
      {:dialyxir, "~> 1.1.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.25.1", only: [:dev], runtime: false},
      {:stream_data, "~> 0.5.0", only: :test},
      # Everything else
      {:gen_stage, "~> 1.0"},
      {:httpoison, "~> 1.0"},
      {:jason, "~> 1.0"},
      {:plug, "~> 1.0"},
      {:telemetry, "~> 1.0"}
    ]
  end

  defp package do
    [
      maintainers: [
        "Pixel Union",
        "Hez Ronningen"
      ],
      links: %{github: "https://github.com/pixelunion/elixir-shopifyapi"},
      licenses: ["Apache2.0"],
      files: ~w(lib test) ++ ~w(CHANGELOG.md LICENSE mix.exs README.md .formatter.exs)
    ]
  end
end
