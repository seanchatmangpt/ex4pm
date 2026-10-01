defmodule Ex4pmEngine.Wasm.PackDriftTest do
  @moduledoc """
  L9 G5: drift court between the ex4pm adapter registry and the live
  `wasm4pm-ex4pm-bindings` crate source.

  Read-only on the crate: the set of `export_name = "..."` strings in
  `$EX4PM_WASM4PM_CRATE_SRC` (default
  `~/wasm4pm/crates/wasm4pm-ex4pm-bindings/src/*.rs`) must equal the export
  names derived from `RealTransport.algo_specs/0` (`<algo>_v1` +
  `<algo>_replay_v1`) plus the crate's own ABI infrastructure exports, and
  each adapter module's `wasm_export/0` must be one of the crate exports.

  The crate path being absent is a typed skip unless `EX4PM_WASM_REQUIRED=1`,
  in which case it is a failure.
  """
  use ExUnit.Case, async: true

  alias Ex4pmEngine.Wasm.{Adapter, RealTransport}

  @crate_src System.get_env("EX4PM_WASM4PM_CRATE_SRC") ||
               Path.expand("~/wasm4pm/crates/wasm4pm-ex4pm-bindings/src")
  @wasm4pm_repo System.get_env("EX4PM_WASM4PM_REPO") || Path.expand("~/wasm4pm")

  # ABI infrastructure exports every host uses; not algorithms.
  @infra_prefix "wasm4pm_ex4pm_bindings_"

  @export_re ~r/export_name\s*=\s*"([^"]+)"/

  defp required?, do: System.get_env("EX4PM_WASM_REQUIRED") == "1"

  @doc false
  def crate_exports(src_dir) do
    src_dir
    |> Path.join("*.rs")
    |> Path.wildcard()
    |> Enum.flat_map(fn f ->
      @export_re |> Regex.scan(File.read!(f), capture: :all_but_first) |> List.flatten()
    end)
    |> MapSet.new()
  end

  @doc false
  # Pure drift check. Returns :ok or a typed refusal naming both sides.
  def drift_check(specs, crate_exports) do
    algo_exports =
      specs
      |> Enum.flat_map(&[&1.export_name, &1.replay_export_name])
      |> MapSet.new()

    crate_algo =
      Enum.reject(crate_exports, &String.starts_with?(&1, @infra_prefix)) |> MapSet.new()

    missing_in_crate = MapSet.difference(algo_exports, crate_algo) |> Enum.sort()
    unregistered_in_ex4pm = MapSet.difference(crate_algo, algo_exports) |> Enum.sort()

    if missing_in_crate == [] and unregistered_in_ex4pm == [] do
      :ok
    else
      {:error,
       {:refused_export_drift,
        missing_in_crate: missing_in_crate, unregistered_in_ex4pm: unregistered_in_ex4pm}}
    end
  end

  setup_all do
    cond do
      File.dir?(@crate_src) ->
        {:ok, crate_exports: crate_exports(@crate_src)}

      required?() ->
        flunk("REFUSED_CRATE_SOURCE_MISSING (EX4PM_WASM_REQUIRED=1): #{@crate_src}")

      true ->
        {:ok, crate_exports: :absent}
    end
  end

  setup %{crate_exports: ce} do
    if ce == :absent,
      do: {:ok, skip_reason: "UNSUPPORTED crate source absent: #{@crate_src}"},
      else: :ok
  end

  defp guard(%{skip_reason: r}, _fun), do: IO.puts("SKIPPED (typed): #{r}")
  defp guard(ctx, fun), do: fun.(ctx)

  test "the spec registry has one entry per algorithm (33), exports derived 1:1" do
    specs = RealTransport.algo_specs()
    assert length(specs) == 33
    assert length(Enum.uniq_by(specs, & &1.algorithm_id)) == 33

    # The L9 "42 id: lines" count is a grep artifact: 33 `algorithm_id: :x`
    # registry rows + 9 unrelated `id:`-suffixed lines (typespec, pid:, the
    # Enum.map destructuring). Registry cardinality is 33.
    for s <- specs do
      assert s.export_name == "wasm4pm_ex4pm_#{s.algorithm_id}_v1"
      assert s.replay_export_name == "wasm4pm_ex4pm_#{s.algorithm_id}_replay_v1"
    end
  end

  test "RealTransport.algo_specs/0 export names equal the live crate's algorithm exports", ctx do
    guard(ctx, fn %{crate_exports: ce} ->
      assert :ok == drift_check(RealTransport.algo_specs(), ce)
    end)
  end

  test "every adapter module's wasm_export/0 is a live crate export", ctx do
    guard(ctx, fn %{crate_exports: ce} ->
      for %{module: mod, export_name: expected} <- RealTransport.algo_specs() do
        assert mod.wasm_export() == expected,
               "#{inspect(mod)}.wasm_export/0 = #{inspect(mod.wasm_export())}, registry says #{inspect(expected)}"

        assert MapSet.member?(ce, mod.wasm_export()),
               "#{inspect(mod)} wasm_export #{inspect(mod.wasm_export())} absent from crate source"
      end
    end)
  end

  test "Adapter @wasm4pm_source_sha is reported and is an ancestor of the wasm4pm checkout HEAD",
       ctx do
    guard(ctx, fn _ ->
      pin = Adapter.wasm4pm_source_sha()

      case System.cmd("git", ["-C", @wasm4pm_repo, "rev-parse", "HEAD"], stderr_to_stdout: true) do
        {head, 0} ->
          head = String.trim(head)
          IO.puts("wasm4pm_source_sha pin=#{pin} checkout_HEAD=#{head}")

          {out, code} =
            System.cmd("git", ["-C", @wasm4pm_repo, "merge-base", "--is-ancestor", pin, head],
              stderr_to_stdout: true
            )

          assert code == 0,
                 "PIN_NOT_ANCESTOR: Adapter pin #{pin} is not an ancestor of wasm4pm HEAD #{head} " <>
                   "(git exit #{code}: #{String.trim(out)})"

        {out, code} ->
          if required?(),
            do: flunk("REFUSED_WASM4PM_REPO_UNREADABLE git exit #{code}: #{out}"),
            else: IO.puts("SKIPPED (typed): wasm4pm repo not a git checkout: #{@wasm4pm_repo}")
      end
    end)
  end

  test "negative control: a mutated export name in an in-memory spec copy yields a typed refusal",
       ctx do
    guard(ctx, fn %{crate_exports: ce} ->
      [first | rest] = RealTransport.algo_specs()
      mutated = [%{first | export_name: first.export_name <> "_DRIFTED"} | rest]

      assert {:error,
              {:refused_export_drift,
               missing_in_crate: missing, unregistered_in_ex4pm: unregistered}} =
               drift_check(mutated, ce)

      assert (first.export_name <> "_DRIFTED") in missing
      assert first.export_name in unregistered
    end)
  end

  test "negative control (no crate needed): drift_check refuses an empty crate and a dropped spec" do
    specs = RealTransport.algo_specs()

    assert {:error, {:refused_export_drift, _}} = drift_check(specs, MapSet.new())

    all =
      specs |> Enum.flat_map(&[&1.export_name, &1.replay_export_name]) |> MapSet.new()

    assert :ok == drift_check(specs, all)
    assert {:error, {:refused_export_drift, _}} = drift_check(tl(specs), all)
  end
end
