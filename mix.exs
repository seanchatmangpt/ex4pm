defmodule Ex4pm.Umbrella.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      deps: [],
      aliases: aliases()
    ]
  end

  defp aliases do
    [
      verify: ["format --check-formatted", "compile --warnings-as-errors", "test"],
      chicago: ["do --app ex4pm test --only chicago --seed 0"]
    ]
  end
end
