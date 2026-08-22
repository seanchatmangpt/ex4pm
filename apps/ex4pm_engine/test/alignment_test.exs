defmodule Ex4pm.Engine.AlignmentTest do
  use ExUnit.Case, async: true

  alias Ex4pmEngine.Alignment

  test "computes 100% synchronous alignment on a perfectly conforming trace" do
    # Sequence Workflow Net: p_in -> [request] -> p_1 -> [approve] -> p_2 -> [deploy] -> p_out
    net = %{
      transitions: %{
        request: %{inputs: ["p_in"], outputs: ["p_1"], label: "request"},
        approve: %{inputs: ["p_1"], outputs: ["p_2"], label: "approve"},
        deploy: %{inputs: ["p_2"], outputs: ["p_out"], label: "deploy"}
      },
      initial_marking: ["p_in"],
      final_marking: ["p_out"]
    }

    trace = ["request", "approve", "deploy"]

    assert {:ok, result} = Alignment.align_trace(trace, net)
    assert result.fitness == 1.0
    assert result.total_cost == 0.0
    assert result.sync_moves_count == 3
    assert result.log_moves_count == 0
    assert result.model_moves_count == 0
  end

  test "identifies model-only moves when an approval activity is skipped" do
    net = %{
      transitions: %{
        request: %{inputs: ["p_in"], outputs: ["p_1"], label: "request"},
        approve: %{inputs: ["p_1"], outputs: ["p_2"], label: "approve"},
        deploy: %{inputs: ["p_2"], outputs: ["p_out"], label: "deploy"}
      },
      initial_marking: ["p_in"],
      final_marking: ["p_out"]
    }

    # Trace skips mandatory "approve"
    trace = ["request", "deploy"]

    assert {:ok, result} = Alignment.align_trace(trace, net)
    assert result.fitness < 1.0
    assert result.model_moves_count == 1
    assert result.sync_moves_count == 2

    assert Enum.any?(result.moves, fn m ->
             m.type == :model_only and m.model_transition == "approve"
           end)
  end

  test "identifies log-only moves when an unexpected rogue action occurs" do
    net = %{
      transitions: %{
        request: %{inputs: ["p_in"], outputs: ["p_1"], label: "request"},
        deploy: %{inputs: ["p_1"], outputs: ["p_out"], label: "deploy"}
      },
      initial_marking: ["p_in"],
      final_marking: ["p_out"]
    }

    # Trace has extra rogue activity "hack_database"
    trace = ["request", "hack_database", "deploy"]

    assert {:ok, result} = Alignment.align_trace(trace, net)
    assert result.log_moves_count == 1
    assert result.sync_moves_count == 2

    assert Enum.any?(result.moves, fn m ->
             m.type == :log_only and m.log_activity == "hack_database"
           end)
  end

  test "handles concurrent fork-join AND parallelism correctly" do
    # Parallel Fork-Join Net:
    # p_in -> [fork] -> {p_a, p_b}
    # p_a -> [task_a] -> p_done_a
    # p_b -> [task_b] -> p_done_b
    # {p_done_a, p_done_b} -> [join] -> p_out
    net = %{
      transitions: %{
        fork: %{inputs: ["p_in"], outputs: ["p_a", "p_b"], label: "fork"},
        task_a: %{inputs: ["p_a"], outputs: ["p_done_a"], label: "task_a"},
        task_b: %{inputs: ["p_b"], outputs: ["p_done_b"], label: "task_b"},
        join: %{inputs: ["p_done_a", "p_done_b"], outputs: ["p_out"], label: "join"}
      },
      initial_marking: ["p_in"],
      final_marking: ["p_out"]
    }

    # Interleaving 1: task_a before task_b
    trace1 = ["fork", "task_a", "task_b", "join"]
    assert {:ok, res1} = Alignment.align_trace(trace1, net)
    assert res1.fitness == 1.0
    assert res1.sync_moves_count == 4

    # Interleaving 2: task_b before task_a (both perfectly valid under concurrency)
    trace2 = ["fork", "task_b", "task_a", "join"]
    assert {:ok, res2} = Alignment.align_trace(trace2, net)
    assert res2.fitness == 1.0
    assert res2.sync_moves_count == 4
  end
end
