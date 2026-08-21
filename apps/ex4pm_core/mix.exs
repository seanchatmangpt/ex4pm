defmodule Ex4pmCore.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex4pm_core,
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
    [extra_applications: [:logger, :crypto, :xmerl]]
  end

  defp deps do
    [{:sweet_xml, "~> 0.7.5"}]
  end
end
