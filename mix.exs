defmodule Ex4pm.Umbrella.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      deps: [{:stream_data, "~> 1.0"}],
      aliases: aliases(),
      preferred_cli_env: [
        verify: :test,
        "test.stress": :test
      ],
      dialyzer: [
        plt_core_path: "priv/plts/core.plt",
        plt_file: {:no_warn, "priv/plts/project.plt"},
        plt_add_apps: [:ex_unit, :mix]
      ]
    ]
  end

  def cli do
    [
      preferred_envs: [
        verify: :test,
        "test.stress": :test
      ]
    ]
  end

  defp aliases do
    [
      verify: ["format --check-formatted", "compile --warnings-as-errors", "test"],
      "test.stress": ["test apps/ex4pm_engine/test/benchmarks/stress_benchmark_test.exs"]
    ]
  end
end
