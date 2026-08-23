defmodule Ex4pmEvidence.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex4pm_evidence,
      version: "26.8.22",
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
    [mod: {Ex4pm.Evidence.Application, []}, extra_applications: [:logger, :crypto]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:ex4pm_core, in_umbrella: true}
    ]
  end
end
