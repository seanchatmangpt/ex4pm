defmodule Ex4pm.EngineTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Ex4pm.Engine
  alias Ex4pm.Ocel

  @raw %{
    "objects" => %{
      "o1" => %{"type" => "Order"},
      "o2" => %{"type" => "Order"}
    },
    "events" => %{
      "e1" => %{
        "activity" => "create",
        "timestamp" => "2026-01-01T00:00:00Z",
        "objects" => ["o1"]
      },
      "e2" => %{
        "activity" => "approve",
        "timestamp" => "2026-01-01T00:01:00Z",
        "objects" => ["o1"]
      },
      "e3" => %{
        "activity" => "create",
        "timestamp" => "2026-01-01T00:02:00Z",
        "objects" => ["o2"]
      },
      "e4" => %{
        "activity" => "reject",
        "timestamp" => "2026-01-01T00:03:00Z",
        "objects" => ["o2"]
      }
    }
  }

  test "native engine executes discovery, conformance, simulation and optimization" do
    assert {:ok, log} = Ocel.ingest(@raw)

    assert {:ok, discovery} = Engine.execute(:discover, log, algorithm: :dfg)
    assert discovery.engine == :beam
    assert discovery.standing == :alive
    assert discovery.value.activities == %{"approve" => 1, "create" => 2, "reject" => 1}

    assert discovery.value.edges[{"create", "approve"}].count == 1
    assert discovery.value.edges[{"create", "reject"}].count == 1

    assert {:ok, conformance} = Engine.execute(:conform, {log, discovery.value})
    assert conformance.value.fitness == 1.0

    assert {:ok, simulation} = Engine.execute(:simulate, discovery.value)
    assert ["create", "approve"] in simulation.value.paths
    assert ["create", "reject"] in simulation.value.paths

    assert {:ok, optimization} = Engine.execute(:optimize, {log, discovery.value})
    assert optimization.value.candidates != []
    assert Enum.all?(optimization.value.candidates, &(&1.mode == :construct_only))
  end

  test "registry preserves candidates without confusing inspection with execution" do
    candidates = Engine.candidates(:discover)

    assert Enum.map(candidates, & &1.id) == [:beam, :ex4pm_plan, :wasm, :nif, :remote]
    assert Enum.find(candidates, &(&1.id == :beam)).standing == :partial_alive
    assert Enum.find(candidates, &(&1.id == :ex4pm_plan)).standing == :unsupported
    assert Enum.find(candidates, &(&1.id == :wasm)).standing == :unsupported
    assert Enum.all?(candidates, fn candidate -> candidate.evidence.executed == false end)
  end

  @tag :tmp_dir
  test "Wasmex executes exact admitted WebAssembly bytes before earning ALIVE", %{
    tmp_dir: tmp_dir
  } do
    wat = """
    (module
      (func $sum (param $left i32) (param $right i32) (result i32)
        local.get $left
        local.get $right
        i32.add)
      (export "sum" (func $sum)))
    """

    wasm_path = Path.join(tmp_dir, "sum.wat")
    File.write!(wasm_path, wat)

    assert {:ok, result} =
             Engine.execute(:wasm, %{wasm_path: wasm_path, export: "sum", params: [20, 22]})

    assert result.engine == :wasm
    assert result.standing == :alive
    assert result.value == 42
    assert result.evidence.executed == true
    assert is_binary(result.evidence.artifact_hash)
  end

  property "BEAM discovery remains deterministic over admitted event permutations" do
    check all(order <- StreamData.shuffle(Map.keys(@raw["events"]))) do
      permuted_events = Map.new(order, &{&1, @raw["events"][&1]})
      assert {:ok, log} = Ocel.ingest(%{@raw | "events" => permuted_events})
      assert {:ok, result} = Engine.execute(:discover, log, algorithm: :dfg)
      assert result.value.activities == %{"approve" => 1, "create" => 2, "reject" => 1}
    end
  end

  property "unsupported algorithm names are refused instead of dynamically dispatched" do
    check all(name <- StreamData.string(:alphanumeric, min_length: 1, max_length: 24)) do
      if name not in ["dfg", "variants"] do
        assert {:ok, log} = Ocel.ingest(@raw)
        assert {:error, %Ex4pm.Refusal{code: :unsupported_algorithm}} =
                 Engine.execute(:discover, log, algorithm: name)
      end
    end
  end
end
