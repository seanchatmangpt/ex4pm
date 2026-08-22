defmodule Ex4pmEngine.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex4pm_engine,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
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
      {:ex4pm_core, in_umbrella: true},
      {:ex4pm_evidence, in_umbrella: true},
      {:jason, "~> 1.4.5"},
      {:wasmex, "~> 0.14"},
      {:explorer, "~> 0.12"}
    ]
  end
end
