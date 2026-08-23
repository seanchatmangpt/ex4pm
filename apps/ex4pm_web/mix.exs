defmodule Ex4pmWeb.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex4pm_web,
      version: "26.8.23",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [mod: {Ex4pmWeb.Application, []}, extra_applications: [:logger, :runtime_tools, :crypto]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:ex4pm_core, in_umbrella: true},
      {:ex4pm_evidence, in_umbrella: true},
      {:ex4pm_engine, in_umbrella: true},
      {:ex4pm_stream, in_umbrella: true},
      {:ex4pm_domain, in_umbrella: true},
      {:ex4pm, in_umbrella: true},
      {:phoenix, "~> 1.7.14"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_view, "~> 1.0"},
      {:ash_phoenix, "~> 2.1"},
      {:ash_admin, "~> 0.12"},
      {:bandit, "~> 1.5"},
      {:jason, "~> 1.4"},
      {:telemetry_metrics, "~> 0.6 or ~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:floki, ">= 0.30.0", only: :test}
    ]
  end

  defp aliases do
    [setup: ["deps.get"], "assets.setup": [], "assets.build": [], "assets.deploy": ["phx.digest"]]
  end
end
