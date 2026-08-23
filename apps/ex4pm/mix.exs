defmodule Ex4pmPublic.MixProject do
  use Mix.Project

  @version "26.8.22"
  @source_url "https://github.com/seanchatmangpt/ex4pm"

  def project do
    [
      app: :ex4pm,
      version: @version,
      description: "Evidence-oriented BEAM process intelligence with Reactor and BRCE",
      source_url: @source_url,
      package: package(),
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application, do: [extra_applications: [:logger, :crypto]]

  defp deps do
    [
      {:ex4pm_contracts, "~> 26.8.22", in_umbrella: true},
      {:ex4pm_core, "~> 26.8.22", in_umbrella: true},
      {:ex4pm_evidence, "~> 26.8.22", in_umbrella: true},
      {:ex4pm_engine, "~> 26.8.22", in_umbrella: true},
      {:ex4pm_runtime, "~> 26.8.22", in_umbrella: true},
      {:ex4pm_stream, "~> 26.8.22", in_umbrella: true},
      {:ex4pm_domain, "~> 26.8.22", in_umbrella: true}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url, "Architecture" => @source_url <> "/blob/main/docs/ARCHITECTURE.md"},
      files: ["lib", "mix.exs"]
    ]
  end
end
