defmodule Pinecone.MixProject do
  use Mix.Project

  def project do
    [
      app: :pinecone,
      version: "0.1.1",
      elixir: "~> 1.12",
      description: "Pinecone.io API integration",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package(),

      preferred_cli_env: [
        dialyzer: :test
      ],

      elixirc_options: [
        warnings_as_errors: true
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
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:blitz_credo_checks, "~> 0.1", only: [:test, :dev], runtime: false},
      {:ex_doc, ">= 0.0.0", optional: true, only: :dev},

      {:jason, "~> 1.4"},
      {:req, "~> 0.3"}
    ]
  end

  defp package do
    [
      maintainers: ["Mika Kalathil"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/theblitzapp/prometheus_telemetry_elixir"},
      files: ~w(mix.exs README.md CHANGELOG.md LICENSE lib config priv)
    ]
  end

  defp docs do
    [
      main: "Pinecone",
      source_url: "https://github.com/mikaak/pinecone"
    ]
  end
end
