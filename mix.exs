defmodule Plug.ShopifyAPI.MixProject do
  use Mix.Project

  @version "0.1.13"

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
        extras: [
          "README.md",
          "guides/installation.md",
          "guides/getting_started.md",
          "guides/graphql.md"
        ]
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
      {:bypass, "~> 0.8", only: :test},
      {:credo, "~> 0.3", only: [:dev, :test]},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:excoveralls, only: [:dev, :test]},
      {:ex_doc, "~> 0.18.3", only: [:dev], runtime: false},
      {:exq, "~> 0.11.0"},
      {:exq_atomize_job_arguments,
       git: "git@github.com:pixelunion/exq-atomize-job-arguments.git", tag: "0.1.0"},
      {:gen_stage, "~> 0.12"},
      {:httpoison, "~> 1.0"},
      {:plug, "~> 1.0"},
      {:poison, "~> 3.1"}
    ]
  end
end
