defmodule Ex4pmEngine.Reactors.FerroplanRepairReactorTest do
  @moduledoc """
  Real ferroplan + real wasm4pm (bundled, digest-pinned artifacts): a logistics
  process deviates (the `drive` step is skipped); the reactor replans from the
  last conformant state, validates the repaired trace with wasm `:conform`, and
  emits a proposed intervention that requires BRCE. No mocks.
  """
  use ExUnit.Case, async: false

  alias Ex4pmEngine.Reactors.FerroplanRepairReactor

  @edges [
    %{from: "receive", to: "load"},
    %{from: "load", to: "drive"},
    %{from: "drive", to: "unload"},
    %{from: "unload", to: "deliver"}
  ]

  defp run(inputs) do
    base = %{model_edges: @edges, traces: nil, deviation: nil, goal: nil, engine_opts: nil}
    {:ok, result} = Reactor.run(FerroplanRepairReactor, Map.merge(base, inputs))
    result
  end

  test "logistics deviation (skipped drive) yields a validated proposal requiring BRCE" do
    result =
      run(%{
        traces: [
          ["receive", "load", "drive", "unload", "deliver"],
          ["receive", "load", "unload"]
        ]
      })

    assert result.status == :proposed
    assert result.repaired_trace == ["receive", "load", "drive", "unload", "deliver"]
    assert result.plan_steps == ["drive", "unload", "deliver"]
    assert result.deviation.resume_from == "load"
    assert result.validation.fitness == 1.0
    assert result.validation.standing == :alive
    assert is_binary(result.validation.result_digest)

    i = result.intervention
    assert i.standing == :partial_alive
    assert i.actuation == :requires_brce
    assert i.actuation_performed == false
    refute is_struct(i)
  end

  test "explicit deviation input is the fallback path" do
    result = run(%{deviation: %{trace: ["receive", "unload"]}})
    assert result.status == :proposed

    assert result.repaired_trace ==
             ["receive", "load", "drive", "unload", "deliver"]
             |> Enum.take(1)
             |> Kernel.++(result.plan_steps)

    assert result.intervention.actuation == :requires_brce
  end

  test "fully conformant traces produce no intervention" do
    result = run(%{traces: [["receive", "load", "drive", "unload", "deliver"]]})
    assert result.status == :no_deviation
    assert result.intervention == nil
  end

  test "unreachable goal is a typed blocked outcome, not a crash" do
    result = run(%{deviation: %{trace: ["receive", "load", "teleport"]}, goal: "nowhere"})
    assert result.status == :blocked
    assert result.intervention == nil
  end
end
