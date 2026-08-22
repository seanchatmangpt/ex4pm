defmodule Ex4pmRuntime.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex4pm_runtime,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [mod: {Ex4pm.Runtime.Application, []}, extra_applications: [:logger, :crypto]]
  end

  defp deps do
    [
      {:ex4pm_core, in_umbrella: true},
      {:ex4pm_evidence, in_umbrella: true},
      {:ex4pm_engine, in_umbrella: true},
      {:ex4pm_domain, in_umbrella: true},
      {:ex4pm_stream, in_umbrella: true},
      {:ash, "~> 3.31"},
      {:phoenix, "~> 1.7"},
      {:phoenix_live_view, "~> 1.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_pubsub, "~> 2.1"},
      {:bandit, "~> 1.5"},
      {:jason, "~> 1.4"}
    ]
  end
end
