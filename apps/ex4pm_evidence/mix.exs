defmodule Ex4pmEvidence.MixProject do
  use Mix.Project

  @version "26.8.22"
  @source_url "https://github.com/seanchatmangpt/ex4pm"

  def project do
    [
      app: :ex4pm_evidence,
      version: @version,
      description: "BRCE receipts, replay and standing evidence for ex4pm",
      source_url: @source_url,
      package: package(),
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      start_permanent: Mix.env() == :prod,
      deps: [{:ex4pm_core, "~> 26.8.22", in_umbrella: true}]
    ]
  end

  def application do
    [mod: {Ex4pm.Evidence.Application, []}, extra_applications: [:logger, :crypto]]
  end

  defp package,
    do: [licenses: ["MIT"], links: %{"GitHub" => @source_url}, files: ["lib", "mix.exs"]]
end
