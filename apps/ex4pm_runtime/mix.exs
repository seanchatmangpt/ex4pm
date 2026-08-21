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
    [{:ex4pm_core, in_umbrella: true}, {:ex4pm_evidence, in_umbrella: true}]
  end
end
