defmodule Pinecone.MixProject do
  use Mix.Project

  def project do
    [
      app: :pinecone,
      version: "0.1.2",
      elixir: "~> 1.12",
      description: "Pinecone.io API integration",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package(),

      test_coverage: [tool: ExCoveralls],

      preferred_cli_env: [
        dialyzer: :test,
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],

      dialyzer: [
        plt_add_apps: [:ex_unit, :mix, :credo],
        list_unused_filters: true,
        plt_local_path: ".dialyzer",
        plt_core_path: ".dialyzer",
        ignore_warnings: ".dialyzer-ignore.exs",
        flags: [:unmatched_returns, :no_improper_lists]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.4"},
      {:req, "~> 0.3"},

      {:excoveralls, "~> 0.10", only: :test},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:blitz_credo_checks, "~> 0.1", only: [:test, :dev], runtime: false},
      {:ex_doc, ">= 0.0.0", optional: true, only: :dev}
    ]
  end

  defp package do
    [
      maintainers: ["Mika Kalathil"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/mikaak/pinecone"},
      files: ~w(mix.exs README.md CHANGELOG.md LICENSE lib config)
    ]
  end

  defp docs do
    [
      main: "Pinecone",
      source_url: "https://github.com/mikaak/pinecone"
    ]
  end
end
