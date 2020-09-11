defmodule Plug.ShopifyAPI.MixProject do
  use Mix.Project

  @version "0.9.1"

  def project do
    [
      app: :shopify_api,
      version: @version,
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [plt_add_deps: :transitive, plt_file: {:no_warn, "priv/plts/dialyzer.plt"}],
      test_coverage: [tool: ExCoveralls],
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
      {:bypass, "~> 1.0", only: :test},
      {:credo, "~> 1.0", only: [:dev, :test]},
      {:dialyxir, "~> 1.0.0-rc.6", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.22.0", only: [:dev], runtime: false},
      {:excoveralls, ">= 0.0.0", only: [:dev, :test]},
      {:stream_data, "~> 0.5.0", only: :test},
      # Everything else
      {:absinthe, "~> 1.5"},
      {:absinthe_plug, "~> 1.5"},
      {:absinthe_phoenix, "~> 2.0"},
      {:gen_stage, "~> 1.0"},
      {:plug_cowboy, "~> 2.3"},
      {:httpoison, "~> 1.0"},
      {:jason, "~> 1.0"},
      {:plug, "~> 1.0"},
      {:telemetry, "~> 0.4.0"}
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
