defmodule Ex4pmCli.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex4pm_cli,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: [main_module: Ex4pm.CLI]
    ]
  end

  def application do
    [extra_applications: [:logger, :crypto]]
  end

  defp deps do
    [
      {:ex4pm_information, in_umbrella: true},
      {:jason, "~> 1.4.5"}
    ]
  end
end
