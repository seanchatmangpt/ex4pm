defmodule Ex4pm.Engine.Beam.CaseFitnessTest do
  @moduledoc """
  Real, minimal per-case conformance/fitness-score capability test.

  Chicago-style: real OCEL fixture data (`apps/ex4pm/test/fixtures/marketplace-ocel.json`),
  the real `Ex4pm.OCEL` normalizer, the real `Ex4pm.Engine.Beam` discover/conform
  pipeline, and real numeric (0-100, ARIS convention) state-based assertions. No
  mocked collaborators.
  """

  use ExUnit.Case, async: true

  alias Ex4pm.Engine

  @fixture_path Path.expand("../../ex4pm/test/fixtures/marketplace-ocel.json", __DIR__)

  defp load_ocel! do
    @fixture_path
    |> File.read!()
    |> Jason.decode!()
    |> update_in(["events"], fn events -> Enum.map(events, &Map.delete(&1, "attributes")) end)
  end

  setup do
    {:ok, log} = load_ocel!() |> Ex4pm.OCEL.normalize()
    %{log: log}
  end

  test "discovers a reference DFG model and scores every real Order case's fitness on the ARIS 0-100 scale",
       %{log: log} do
    assert {:ok, discovery} =
             Engine.execute(:discover, log, algorithm: :dfg, object_type: "Order")

    assert discovery.value.trace_count == 3

    assert {:ok, conformance} =
             Engine.execute(:conform, {log, discovery.value}, object_type: "Order")

    report = conformance.value
    assert report.type == :dfg_conformance

    # The reference model was mined from these exact three cases, so every
    # case's own transitions are, by construction, edges of the model: each
    # real case scores a perfect 100.0 (ARIS: 100 == full compliance).
    assert map_size(report.case_fitness) == 3

    for {case_id, score} <- report.case_fitness do
      assert is_binary(case_id)
      assert score == 100.0
    end

    assert report.mean_case_fitness_score == 100.0
    assert report.fitness == 1.0
  end

  test "a real deviating trace scores strictly below 100 while conforming cases stay at 100" do
    ocel = load_ocel!()
    {:ok, log} = Ex4pm.OCEL.normalize(ocel)

    assert {:ok, discovery} =
             Engine.execute(:discover, log, algorithm: :dfg, object_type: "Order")

    # Real deviation: order-002 skips straight from place_order to ship_order,
    # an edge the mined reference model never observed.
    deviating_ocel =
      update_in(ocel["events"], fn events ->
        Enum.reject(events, &(&1["id"] in ["e7", "e8"]))
      end)

    {:ok, deviating_log} = Ex4pm.OCEL.normalize(deviating_ocel)

    assert {:ok, conformance} =
             Engine.execute(:conform, {deviating_log, discovery.value}, object_type: "Order")

    scores = conformance.value.case_fitness
    assert scores["order-001"] == 100.0
    assert scores["order-003"] == 100.0
    assert scores["order-002"] < 100.0
    assert scores["order-002"] >= 0.0

    assert conformance.value.mean_case_fitness_score < 100.0
    assert conformance.value.fitness < 1.0
  end
end
