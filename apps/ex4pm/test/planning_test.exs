defmodule Ex4pm.PlanningTest do
  use ExUnit.Case, async: false

  alias Ex4pm.Engine.Ex4pmPlan

  @problem %{
    type: :deterministic_graph,
    initial: "A",
    goals: ["G"],
    edges: [
      %{from: "A", to: "B", action: "to_b", cost: 1},
      %{from: "B", to: "G", action: "to_g", cost: 1}
    ]
  }

  test "plan is an analytical receipted run and does not cross operate/DO" do
    transport = fn request, _opts ->
      assert request["problem"]["type"] == "deterministic_graph"

      {:ok,
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
       },
       %{
         observed: true,
         source_sha: Ex4pmPlan.source_sha(),
         image_digest: "sha256:planner-image"
       }}
    end

    assert {:ok, run} = Ex4pm.plan(@problem, ex4pm_plan_fun: transport)
    assert run.operation == :plan
    assert run.standing == :alive
    assert run.engine_result.engine == :ex4pm_plan
    assert run.value["total_cost"] == 2.0
    assert {:ok, %{replay: :chain_match}} = Ex4pm.replay(run.receipt.hash)
  end
end
