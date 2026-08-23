defmodule Ex4pmEngine.MixProject do
  use Mix.Project

  @version "26.8.22"
  @source_url "https://github.com/seanchatmangpt/ex4pm"

  def project do
    [
      app: :ex4pm_engine,
      version: @version,
      description: "Evidence-ranked process-intelligence engine graph for ex4pm",
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

  def application, do: [extra_applications: [:logger, :crypto]]
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:ex4pm_core, "~> 26.8.22", in_umbrella: true},
      {:ex4pm_evidence, "~> 26.8.22", in_umbrella: true},
      {:jason, "~> 1.4.5"},
      {:wasmex, "~> 0.14"},
      {:explorer, "~> 0.12"},
      {:reactor, "~> 1.0"}
    ]
  end

  defp package,
    do: [licenses: ["MIT"], links: %{"GitHub" => @source_url}, files: ["lib", "mix.exs"]]
end
