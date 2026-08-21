defmodule Ex4pmDomain.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex4pm_domain,
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
    [extra_applications: [:logger, :crypto]]
  end

  defp deps do
    [{:ex4pm_core, in_umbrella: true}, {:ex4pm_evidence, in_umbrella: true}, {:ex4pm_engine, in_umbrella: true}, {:ash, "~> 3.31"}]
  end
end
