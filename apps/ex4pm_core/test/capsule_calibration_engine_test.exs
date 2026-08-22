defmodule Ex4pmCore.CapsuleCalibrationEngineTest do
  use ExUnit.Case, async: true

  alias Ex4pmCore.CapsuleGraph.Calibration.{Engine, Model, Receipt, Source, Trial, Witness}

  test "calibrated independent greens qualify boundedly and explicit failure dominates" do
    now = DateTime.from_unix!(1_700_000_100)
    {:ok, source_a} = Source.new("gha", "run-a", "artifact-a", "family-a")
    {:ok, source_b} = Source.new("beam", "run-b", "artifact-b", "family-b")
    model_a = model(source_a.fingerprint, now)
    model_b = model(source_b.fingerprint, DateTime.add(now, -20, :second))
    {:ok, wa} = Witness.new("attempt-1", source_a.fingerprint, :pass, now, "repository")
    {:ok, wb} = Witness.new("attempt-1", source_b.fingerprint, :pass, now, "repository")

    input = %{
      models: %{source_a.fingerprint => model_a, source_b.fingerprint => model_b},
      witnesses: [wa, wb],
      now: now,
      min_trials: 4,
      independent_clusters: 2,
      required_clusters: 2,
      accept_threshold: 1.0,
      reject_threshold: -1.0
    }

    assert {:ok, qualified} = Engine.qualify(input)
    assert qualified.standing == :partial_alive
    assert qualified.actuation_performed == false
    assert Receipt.replay(qualified.receipt) == :match

    {:ok, failed} = Witness.new("attempt-1", source_b.fingerprint, :fail, now, "repository")
    assert {:ok, rejected} = Engine.qualify(%{input | witnesses: [wa, failed]})
    assert rejected.standing == :build_broken
  end

  defp model(source_id, base) do
    trials =
      [
        {:pass, :pass},
        {:pass, :pass},
        {:fail, :fail},
        {:fail, :fail}
      ]
      |> Enum.with_index()
      |> Enum.map(fn {{truth, prediction}, i} ->
        {:ok, trial} = Trial.new(source_id, truth, prediction, DateTime.add(base, -10 - i, :second))
        trial
      end)

    {:ok, model} = Model.fit(trials)
    model
  end
end
