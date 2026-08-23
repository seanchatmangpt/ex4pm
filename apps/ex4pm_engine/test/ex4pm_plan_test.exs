defmodule Ex4pm.Engine.Ex4pmPlanTest do
  use ExUnit.Case, async: true

  alias Ex4pm.Engine
  alias Ex4pm.Engine.Ex4pmPlan
  alias Ex4pm.Refusal

  @problem %{
    type: :deterministic_graph,
    initial: "A",
    goals: ["G"],
    edges: [
      %{from: "A", to: "B", action: "to_b", cost: 1},
      %{from: "B", to: "G", action: "to_g", cost: 1}
    ]
  }

  test "observed pinned worker identity plus replay proof reaches ALIVE" do
    transport = fn request, _opts ->
      assert request["solver"] == "astar"
      assert request["problem"]["type"] == "deterministic_graph"

      {:ok, worker_response(),
       %{
         observed: true,
         source_sha: Ex4pmPlan.source_sha(),
         image_digest: "sha256:planner-image"
       }}
    end

    assert {:ok, result} =
             Engine.execute(:plan, @problem,
               engine: :ex4pm_plan,
               ex4pm_plan_fun: transport
             )

    assert result.engine == :ex4pm_plan
    assert result.algorithm == :astar
    assert result.standing == :alive
    assert result.evidence.replay_verified
    assert result.evidence.identity_observed
    assert result.evidence.worker_source_sha == Ex4pmPlan.source_sha()
  end

  test "executed worker response without observed capsule identity remains PARTIAL_ALIVE" do
    transport = fn _request, _opts -> {:ok, worker_response()} end

    assert {:ok, result} =
             Engine.execute(:plan, @problem,
               engine: :ex4pm_plan,
               ex4pm_plan_fun: transport
             )

    assert result.standing == :partial_alive
    refute result.evidence.identity_observed
    assert result.evidence.executed
  end

  test "observed wrong source identity is refused" do
    transport = fn _request, _opts ->
      {:ok, worker_response(),
       %{observed: true, source_sha: "wrong", image_digest: "sha256:wrong"}}
    end

    assert {:error, %Refusal{code: :ex4pm_plan_identity_mismatch}} =
             Engine.execute(:plan, @problem,
               engine: :ex4pm_plan,
               ex4pm_plan_fun: transport
             )
  end

  test "registry preserves supported-but-unavailable planner as BLOCKED" do
    blocked = Engine.candidates(:plan)
    assert %{id: :ex4pm_plan, standing: :blocked} = Enum.find(blocked, &(&1.id == :ex4pm_plan))

    transport = fn _request, _opts -> {:ok, worker_response()} end
    candidates = Engine.candidates(:plan, ex4pm_plan_fun: transport)
    assert %{id: :ex4pm_plan, standing: :partial_alive} = Enum.find(candidates, &(&1.id == :ex4pm_plan))
  end

  defp worker_response do
    %{
      "protocol" => Ex4pmPlan.protocol(),
      "status" => "ok",
      "standing" => "ALIVE",
      "result" => %{
        "solved" => true,
        "steps" => [
          %{"from" => "A", "action" => "to_b", "to" => "B", "cost" => 1.0},
          %{"from" => "B", "action" => "to_g", "to" => "G", "cost" => 1.0}
        ],
        "total_cost" => 2.0
      },
      "evidence" => %{
        "subject_hash" => "sha256:worker-subject",
        "result_hash" => "sha256:worker-result",
        "replay_verified" => true
      }
    }
  end
end
