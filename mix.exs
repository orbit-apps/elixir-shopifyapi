defmodule Plug.ShopifyAPI.MixProject do
  use Mix.Project

  @version "0.2.1"

  def project do
    [
      app: :shopify_api,
      version: @version,
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [plt_add_deps: :transitive],
      test_coverage: [tool: ExCoveralls],

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
      extra_applications: [:logger, :exq]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:absinthe_plug, "~> 1.4.0"},
      {:absinthe, "~> 1.4.0"},
      {:bypass, "~> 1.0", only: :test},
      {:credo, "~> 1.0", only: [:dev, :test]},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:excoveralls, ">= 0.0.0", only: [:dev, :test]},
      {:ex_doc, "~> 0.19.1", only: [:dev], runtime: false},
      {:exq, "~> 0.13.0"},
      {:exq_atomize_job_arguments, github: "pixelunion/exq-atomize-job-arguments", tag: "v0.1.2"},
      {:gen_stage, "~> 0.12"},
      {:httpoison, "~> 1.0"},
      {:plug, "~> 1.0"},
      {:poison, "~> 3.1"},
      {:stream_data, "~> 0.4.2", only: :test}
    ]
  end
end
