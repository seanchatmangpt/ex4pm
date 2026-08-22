defmodule Ex4pm.RuntimeTest do
  use ExUnit.Case, async: false

  alias Ex4pm.POWL
  alias Ex4pm.Runtime

  @authority %{id: "test", capabilities: [:do]}

  test "POWL compiles into Reactor while preserving analytical layers and BRCE receipts" do
    assert {:ok, model} = diamond_model()
    assert {:ok, plan} = Runtime.compile(model)

    assert %Reactor{} = plan.reactor
    assert plan.reactor.steps == []
    refute is_nil(plan.reactor.plan)
    assert plan.metadata.execution_kernel == Reactor
    assert plan.metadata.ash_extension == Ash.Reactor
    assert plan.metadata.scheduler == Reactor.Executor
    assert Process.whereis(Ex4pm.Runtime.TaskSupervisor) == nil

    assert Enum.map(plan.layers, &Enum.map(&1, fn task -> task.id end)) == [
             ["a"],
             ["b", "c"],
             ["d"]
           ]

    assert {:ok, execution} = Runtime.execute(plan, @authority)
    assert execution.standing == :alive
    assert execution.runtime == :reactor
    assert execution.reactor_state == :successful
    assert length(execution.receipt_hashes) == 4

    assert Enum.map(execution.layers, &Enum.map(&1, fn result -> result.task_id end)) == [
             ["a"],
             ["b", "c"],
             ["d"]
           ]
  end

  test "Reactor preserves the public typed refusal contract" do
    assert {:ok, model} = POWL.new([%{id: "a", label: "A"}], [])
    assert {:ok, plan} = Runtime.compile(model)

    assert {:error, %{failure: %Ex4pm.Refusal{code: :authority_required}}} =
             Runtime.execute(plan, nil)
  end

  test "incomparable POWL tasks are scheduled concurrently by Reactor" do
    assert {:ok, model} = diamond_model()
    assert {:ok, plan} = Runtime.compile(model)

    parent = self()

    executor = fn task ->
      case task.id do
        id when id in ["b", "c"] ->
          send(parent, {:ready, id, self()})

          receive do
            :release -> id
          after
            2_000 -> raise "concurrency barrier timed out"
          end

        "d" ->
          send(parent, {:ran, "d"})
          "d"

        id ->
          id
      end
    end

    run =
      Task.async(fn ->
        Runtime.execute(plan, @authority,
          task_executor: executor,
          max_concurrency: 2,
          timeout: 5_000
        )
      end)

    started =
      for _ <- 1..2 do
        receive do
          {:ready, id, pid} -> {id, pid}
        after
          2_000 -> flunk("Reactor did not make both incomparable tasks concurrently ready")
        end
      end

    assert started |> Enum.map(&elem(&1, 0)) |> MapSet.new() == MapSet.new(["b", "c"])
    refute_receive {:ran, "d"}, 100

    Enum.each(started, fn {_id, pid} -> send(pid, :release) end)

    assert {:ok, execution} = Task.await(run, 5_000)
    assert execution.standing == :alive
    assert_receive {:ran, "d"}, 1_000
  end

  test "Reactor cannot silently retry a failed BRCE task" do
    assert {:ok, model} = POWL.new([%{id: "a", label: "A"}], [])
    assert {:ok, plan} = Runtime.compile(model)

    parent = self()

    executor = fn task ->
      send(parent, {:attempt, task.id})
      raise "expected failure"
    end

    assert {:error, %{failure: _reason, completed_layers: []}} =
             Runtime.execute(plan, @authority, task_executor: executor)

    assert_receive {:attempt, "a"}, 1_000
    refute_receive {:attempt, "a"}, 200
  end

  test "cyclic POWL is refused before Reactor construction" do
    assert {:error, %Ex4pm.Refusal{code: :cyclic_powl}} =
             POWL.new([%{id: "a"}, %{id: "b"}], [{"a", "b"}, {"b", "a"}])
  end

  defp diamond_model do
    POWL.new(
      [
        %{id: "a", label: "A"},
        %{id: "b", label: "B"},
        %{id: "c", label: "C"},
        %{id: "d", label: "D"}
      ],
      [{"a", "b"}, {"a", "c"}, {"b", "d"}, {"c", "d"}]
    )
  end
end
