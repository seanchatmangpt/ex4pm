defmodule Ex4pmInformation.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex4pm_information,
      version: "26.8.22",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [extra_applications: [:logger, :crypto]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:ex4pm, in_umbrella: true},
      {:ex4pm_core, in_umbrella: true},
      {:ex4pm_domain, in_umbrella: true},
      {:ex4pm_evidence, in_umbrella: true},
      {:ash, "~> 3.31"},
      {:jason, "~> 1.4.5"},
      {:reactor, "~> 1.0"}
    ]
  end
end
