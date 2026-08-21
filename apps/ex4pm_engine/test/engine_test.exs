defmodule Ex4pm.EngineTest.NifProbe do
  def simulate(subject, _opts), do: {:ok, %{echo: subject}}
end

defmodule Ex4pm.EngineTest do
  use ExUnit.Case, async: true

  alias Ex4pm.Engine

  @ocel %{
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

  test "BEAM DFG discovery, conformance, simulation, and optimization execute" do
    assert {:ok, log} = Ex4pm.OCEL.normalize(@ocel)

    assert {:ok, discovery} =
             Engine.execute(:discover, log, algorithm: :dfg, object_type: "Order")

    assert discovery.standing == :alive
    assert discovery.value.edges[{"create", "approve"}].count == 1
    assert discovery.value.edges[{"create", "reject"}].count == 1

    assert {:ok, conformance} =
             Engine.execute(:conform, {log, discovery.value}, object_type: "Order")

    assert conformance.value.fitness == 1.0

    assert {:ok, simulation} = Engine.execute(:simulate, discovery.value, max_depth: 5)
    assert ["create", "approve"] in simulation.value.paths
    assert ["create", "reject"] in simulation.value.paths

    assert {:ok, optimization} = Engine.execute(:optimize, {log, discovery.value})
    assert optimization.value.candidates != []
    assert Enum.all?(optimization.value.candidates, &(&1.mode == :construct_only))
  end

  test "registry preserves candidates without confusing inspection with execution" do
    candidates = Engine.candidates(:discover)
    assert Enum.map(candidates, & &1.id) == [:beam, :wasm, :nif, :remote]
    assert Enum.find(candidates, &(&1.id == :beam)).standing == :partial_alive
    assert Enum.find(candidates, &(&1.id == :wasm)).standing == :unsupported
    assert Enum.all?(candidates, fn candidate -> candidate.evidence.executed == false end)
  end

  @tag :tmp_dir
  test "Wasmex executes exact admitted WebAssembly bytes before earning ALIVE", %{tmp_dir: tmp_dir} do
    wat = """
    (module
      (func $sum (param $left i32) (param $right i32) (result i32)
        local.get $left
        local.get $right
        i32.add)
      (export "sum" (func $sum)))
    """

    path = Path.join(tmp_dir, "sum.wat")
    File.write!(path, wat)

    contract = %{
      simulate: %{
        export: "sum",
        params: [50, -8],
        algorithm: :wasm_sum_probe,
        timeout: 5_000
      }
    }

    assert {:ok, result} =
             Engine.execute(:simulate, %{probe: true},
               engine: :wasm,
               wasm_path: path,
               wasm_contract: contract
             )

    assert result.value == [42]
    assert result.standing == :alive
    assert result.evidence.runtime == :wasmex_wasmtime
    assert result.evidence.executed == true
    assert result.evidence.artifact_hash =~ "sha256:"
  end

  test "NIF-shaped callbacks remain PARTIAL_ALIVE without native identity proof" do
    assert {:ok, result} =
             Engine.execute(:simulate, %{probe: true},
               engine: :nif,
               nif_module: Ex4pm.EngineTest.NifProbe
             )

    assert result.value == %{echo: %{probe: true}}
    assert result.standing == :partial_alive
    assert result.evidence.native_identity == :unproven
  end

  test "differential standing is capped by the weakest executed engine evidence" do
    model = %{
      type: :dfg,
      edges: %{{"a", "b"} => %{count: 1, average_duration_ms: 1}},
      starts: %{"a" => 1},
      ends: %{"b" => 1}
    }

    remote_fun = fn :simulate, subject, opts ->
      {:ok, result} = Ex4pm.Engine.Beam.execute(:simulate, subject, opts)
      {:ok, result.value}
    end

    assert {:ok, comparison} =
             Ex4pm.Engine.Differential.compare(:simulate, model, :beam, :remote,
               remote_fun: remote_fun
             )

    assert comparison.equivalent
    assert comparison.standing == :partial_alive
  end
end
