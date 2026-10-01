defmodule Ex4pm.Qualification.ExposureCourtTest do
  @moduledoc """
  Chicago-style court tests: the real tree is judged by the real court (real
  AlgoRegistry, real wasm export section, real ferroplan manifest, real
  Wasmex execution), and sabotage cases mutate the court's INPUT data (remove a
  subject / adapter / export / source) and require a typed refusal -- proving
  the court is not vacuous.
  """
  use ExUnit.Case, async: false

  alias Ex4pm.Qualification.ExposureCourt, as: Court
  alias Ex4pm.Qualification.LieFinder

  setup_all do
    {:ok, inputs: Court.load_inputs()}
  end

  defp terms(violations), do: Enum.map(violations, &{&1.broken_term, &1.subject})

  # Violations for the unmutated tree, used as the baseline sabotage must exceed.
  defp baseline(inputs), do: MapSet.new(terms(Court.violations(inputs)))

  defp new_violations(mutated, inputs) do
    base = baseline(inputs)
    mutated |> Court.violations() |> terms() |> Enum.reject(&MapSet.member?(base, &1))
  end

  describe "real tree" do
    test "subjects come from the sources of truth", %{inputs: inputs} do
      assert length(inputs.algorithms) == 33
      assert length(inputs.ferroplan_ops) == 34
      assert {:ok, exported} = inputs.artifact_exports

      declared = Enum.flat_map(inputs.algorithms, &[&1.export_name, &1.replay_export_name])
      # artifact export section == AlgoRegistry export names (+ 4 core + memory)
      assert Enum.sort(exported -- (exported -- declared)) == Enum.sort(declared)
      assert length(exported -- declared) == 5
      refute Enum.any?(Court.violations(inputs), &(&1.layer == :export_drift))
    end

    test "static court admits the tree; every tolerated gap is a declared known gap" do
      assert {:ok, receipt} = Court.run()
      assert receipt.subjects == %{algorithms: 33, wasm_exports: 66, ferroplan_ops: 34}
      assert length(Court.known_gaps()) <= 0, "known-gap list may only shrink"

      assert Enum.all?(Court.known_gaps(), fn {_layer, _matcher, owner} ->
               String.starts_with?(owner, "TODO owner=")
             end)
    end

    test "a stale known gap is itself refused (the list cannot hide a regression)" do
      stale = {:no_real_test, {:ferroplan_op, "plan"}, "TODO owner=nobody"}

      assert {:refused, [violation]} = Court.run(known_gaps: [stale])
      assert violation.broken_term == "REFUSED_EXPOSURE_STALE_KNOWN_GAP"
      assert {:known_gap, _} = violation.subject
    end

    test "session ops map onto Sessions/Session and every op has a real test", %{inputs: inputs} do
      session_ops = Enum.filter(inputs.ferroplan_ops, &String.starts_with?(&1, "session_"))
      assert length(session_ops) == 25

      assert Enum.all?(session_ops, fn "session_" <> name ->
               name in Ex4pm.Engine.Ferroplan.Session.ops()
             end)

      assert function_exported?(Ex4pm.Engine.Ferroplan.Sessions, :call, 4)

      assert Enum.filter(
               Court.violations(inputs),
               &(&1.subject in for(o <- session_ops, do: {:ferroplan_op, o}))
             ) == []
    end

    test "real tests of facade-named ops are detected (htn_plan -> hierarchical_plan)", %{
      inputs: inputs
    } do
      for op <- ~w(plan_production htn_plan fond_policy hddl_solve explain) do
        refute Enum.any?(
                 Court.violations(inputs),
                 &(&1.subject == {:ferroplan_op, op} and &1.layer == :no_real_test)
               )
      end
    end

    test "--require-real executes all 33 algorithms and the ferroplan core ops, all :alive" do
      assert {:ok, receipt} = Court.run(require_real: true)
      executed = receipt.executed
      assert length(for %{subject: {:algorithm, _}} <- executed, do: 1) == 33

      assert Enum.sort(for %{subject: {:ferroplan_op, op}} <- executed, do: op) ==
               ["plan", "readiness", "version"]

      assert Enum.all?(executed, &(&1.standing == :alive))
    end
  end

  describe "sabotage: the court refuses when a subject is removed" do
    test "adapter module removed -> NO_ADAPTER (and NO_DOC)", %{inputs: inputs} do
      [first | rest] = inputs.algorithms
      ghost = %{first | module: Ex4pmEngine.Wasm.RemovedAdapter}
      new = new_violations(%{inputs | algorithms: [ghost | rest]}, inputs)
      assert {"REFUSED_EXPOSURE_NO_ADAPTER", {:algorithm, first.algorithm_id}} in new
      assert {"REFUSED_EXPOSURE_NO_DOC", {:algorithm, first.algorithm_id}} in new
    end

    test "engine registry entry removed -> NO_ENGINE_OP", %{inputs: inputs} do
      [first | _] = inputs.algorithms
      engines = List.delete(inputs.engines, first.module)
      new = new_violations(%{inputs | engines: engines}, inputs)
      assert {"REFUSED_EXPOSURE_NO_ENGINE_OP", {:algorithm, first.algorithm_id}} in new
    end

    test "export dropped from / added to the artifact -> EXPORT_DRIFT", %{inputs: inputs} do
      {:ok, exported} = inputs.artifact_exports
      victim = "wasm4pm_ex4pm_mean_v1"
      assert victim in exported

      dropped = new_violations(%{inputs | artifact_exports: {:ok, exported -- [victim]}}, inputs)
      assert {"REFUSED_EXPOSURE_EXPORT_DRIFT", {:wasm_export, victim}} in dropped

      extra = "wasm4pm_ex4pm_phantom_v1"
      added = new_violations(%{inputs | artifact_exports: {:ok, [extra | exported]}}, inputs)
      assert {"REFUSED_EXPOSURE_EXPORT_DRIFT", {:wasm_export, extra}} in added
    end

    test "unreadable artifact -> ARTIFACT_MISSING", %{inputs: inputs} do
      new = new_violations(%{inputs | artifact_exports: {:error, :enoent}}, inputs)
      assert {"REFUSED_EXPOSURE_ARTIFACT_MISSING", {:wasm_export, "*"}} in new
    end

    test "all real tests removed -> NO_REAL_TEST for every algorithm", %{inputs: inputs} do
      new = new_violations(%{inputs | tests: %{}}, inputs)

      for spec <- inputs.algorithms do
        assert {"REFUSED_EXPOSURE_NO_REAL_TEST", {:algorithm, spec.algorithm_id}} in new
      end
    end

    test "new ferroplan op in the manifest with no handler -> every ferroplan layer", %{
      inputs: inputs
    } do
      new = new_violations(%{inputs | ferroplan_ops: ["bogus_op" | inputs.ferroplan_ops]}, inputs)
      subject = {:ferroplan_op, "bogus_op"}

      for term <- ~w(NO_ADAPTER NO_ENGINE_OP NO_PUBLIC_FUNCTION NO_REAL_TEST) do
        assert {"REFUSED_EXPOSURE_" <> term, subject} in new
      end
    end

    test "an @unsupported entry WITH a reason satisfies engine-op and public-function layers",
         %{inputs: inputs} do
      sources =
        Map.put(inputs.ferroplan_sources, "unsupported.ex", """
        defmodule Unsup do
          @unsupported %{"bogus_op" => "not exposed: needs a stateful session API"}
          def unsupported, do: @unsupported
        end
        """)

      mutated = %{
        inputs
        | ferroplan_ops: ["bogus_op" | inputs.ferroplan_ops],
          ferroplan_sources: sources
      }

      new = new_violations(mutated, inputs)
      subject = {:ferroplan_op, "bogus_op"}
      refute {"REFUSED_EXPOSURE_NO_ENGINE_OP", subject} in new
      refute {"REFUSED_EXPOSURE_NO_PUBLIC_FUNCTION", subject} in new
      # but it is still untested -- unsupported does not excuse the real-test layer
      assert {"REFUSED_EXPOSURE_NO_REAL_TEST", subject} in new

      # an @unsupported entry without a reason does not count
      reasonless =
        Map.put(inputs.ferroplan_sources, "unsupported.ex", """
        defmodule Unsup do
          @unsupported %{"bogus_op" => nil}
        end
        """)

      new2 =
        new_violations(
          %{mutated | ferroplan_sources: reasonless},
          inputs
        )

      assert {"REFUSED_EXPOSURE_NO_PUBLIC_FUNCTION", subject} in new2
    end

    test "session op unknown to Session.ops/0 -> adapter/engine-op/real-test refusals", %{
      inputs: inputs
    } do
      new =
        new_violations(
          %{inputs | ferroplan_ops: ["session_bogus" | inputs.ferroplan_ops]},
          inputs
        )

      subject = {:ferroplan_op, "session_bogus"}

      for term <- ~w(NO_ADAPTER NO_ENGINE_OP NO_REAL_TEST) do
        assert {"REFUSED_EXPOSURE_" <> term, subject} in new
      end
    end

    test "removing the session tests -> NO_REAL_TEST for every session op", %{inputs: inputs} do
      tests = Map.reject(inputs.tests, fn {path, _} -> String.contains?(path, "session") end)
      new = new_violations(%{inputs | tests: tests}, inputs)

      for "session_" <> _ = op <- inputs.ferroplan_ops do
        assert {"REFUSED_EXPOSURE_NO_REAL_TEST", {:ferroplan_op, op}} in new
      end
    end

    test "--require-real with a bogus artifact path is refused, not skipped", %{inputs: inputs} do
      {violations, executed} =
        Court.real_violations(inputs,
          wasm_artifact: "/nonexistent/wasm4pm.wasm",
          ferroplan_artifact: "/nonexistent/ferroplan.wasm"
        )

      assert executed == []
      assert {"REFUSED_EXPOSURE_ARTIFACT_MISSING", {:wasm_export, "*"}} in terms(violations)

      assert Enum.sort(
               for %{layer: :not_alive, subject: {:ferroplan_op, op}} <- violations, do: op
             ) ==
               ["plan", "readiness", "version"]
    end

    test "an unguarded skip of a real-artifact test -> SKIPPED_REAL_EXEC", %{inputs: inputs} do
      bad = """
      defmodule BadTest do
        use ExUnit.Case
        @moduletag skip: "wasm4pm artifact not built"
        test "x", do: Ex4pm.Test.WasmArtifact.path()
      end
      """

      new =
        new_violations(%{inputs | tests: Map.put(inputs.tests, "test/bad_test.exs", bad)}, inputs)

      assert {"REFUSED_EXPOSURE_SKIPPED_REAL_EXEC", {:test_file, "test/bad_test.exs"}} in new
    end
  end

  describe "LieFinder :skipped_real_exec" do
    test "flags unguarded skip, accepts skip_reason/EX4PM_WASM_REQUIRED handling" do
      bad = "@moduletag skip: true\nEx4pm.Test.WasmArtifact.path()\n"

      assert [%{rule: :skipped_real_exec, line: 1}] =
               LieFinder.scan_test_source("t_test.exs", bad)

      good = "if r = Ex4pm.Test.WasmArtifact.skip_reason() do\n @moduletag skip: r\nend\n"
      assert [] == LieFinder.scan_test_source("t_test.exs", good)

      env = "# EX4PM_WASM_REQUIRED\n@describetag :skip\nRealTransport.start(x)\n"
      assert [] == LieFinder.scan_test_source("t_test.exs", env)

      unrelated = "@moduletag :skip\nassert 1 == 1\n"
      assert [] == LieFinder.scan_test_source("t_test.exs", unrelated)
    end
  end
end
