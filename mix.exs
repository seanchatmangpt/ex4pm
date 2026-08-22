defmodule Ex4pm.Umbrella.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      deps: [],
      aliases: aliases(),
      preferred_cli_env: [verify: :test]
    ]
  end

  def cli do
    [
      preferred_envs: [verify: :test]
    ]
  end

  defp aliases do
    [
      verify: ["format --check-formatted", "compile --warnings-as-errors", "test"]
    ]
  end
end
