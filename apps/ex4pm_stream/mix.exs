defmodule Ex4pmStream.MixProject do
  use Mix.Project

  @version "26.8.22"
  @source_url "https://github.com/seanchatmangpt/ex4pm"

  def project do
    [
      app: :ex4pm_stream,
      version: @version,
      description: "Backpressured observation streaming for ex4pm",
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
      {:ex4pm_engine, "~> 26.8.22", in_umbrella: true},
      {:ex4pm_domain, "~> 26.8.22", in_umbrella: true},
      {:broadway, "~> 1.3"},
      {:phoenix_pubsub, "~> 2.1"},
      {:plug, "~> 1.14"},
      {:jason, "~> 1.4"},
      {:telemetry_metrics_prometheus_core, "~> 1.2"}
    ]
  end

  defp package,
    do: [licenses: ["MIT"], links: %{"GitHub" => @source_url}, files: ["lib", "mix.exs"]]
end
