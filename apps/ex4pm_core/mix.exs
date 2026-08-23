defmodule Ex4pmCore.MixProject do
  use Mix.Project

  @version "26.8.23"
  @source_url "https://github.com/seanchatmangpt/ex4pm"

  def project do
    [
      app: :ex4pm_core,
      version: @version,
      description: "Canonical semantic core for ex4pm process intelligence",
      source_url: @source_url,
      package: package(),
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application, do: [extra_applications: [:logger, :crypto, :xmerl]]
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
  defp deps, do: [{:ash, "~> 3.31"}, {:sweet_xml, "~> 0.7.5"}]

  defp package,
    do: [licenses: ["MIT"], links: %{"GitHub" => @source_url}, files: ["lib", "mix.exs"]]
end
