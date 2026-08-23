defmodule Ex4pmQualification.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex4pm_qualification,
      version: "26.8.23",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.17",
      start_permanent: false,
      deps: deps()
    ]
  end

  def application, do: [extra_applications: [:logger, :crypto, :inets, :ssl]]

  defp deps do
    [
      {:ex4pm_contracts, in_umbrella: true},
      {:ex4pm_core, in_umbrella: true},
      {:ex4pm_evidence, in_umbrella: true},
      {:ex4pm_engine, in_umbrella: true},
      {:ex4pm_runtime, in_umbrella: true},
      {:jason, "~> 1.4"}
    ]
  end
end
