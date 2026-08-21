defmodule Ex4pmStream.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex4pm_stream,
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
    [{:ex4pm_core, in_umbrella: true}, {:broadway, "~> 1.3"}]
  end
end
