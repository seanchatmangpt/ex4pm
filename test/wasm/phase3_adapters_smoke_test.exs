defmodule Ex4pmEngine.Wasm.Phase3AdaptersSmokeTest do
  @moduledoc """
  Contract-shape coverage for the 6 Phase-3 wasm4pm-ex4pm-bindings adapters
  (align, etc_precision, soundness, playout, oc_discover, prolog_query) —
  each a thin wrapper over an algorithm that was deferred in Phase 2 as
  JsValue-locked and turned out, on real investigation, to already be a
  plain `pub fn` (align/etc_precision/soundness/playout/oc_discover) or to
  need a real end-to-end integration (prolog_query, prolog8's `Kernel`).
  See `Ex4pmEngine.Wasm.DiscoverTest` for the full ALIVE/PARTIAL_ALIVE/
  typed-refusal matrix this shared `Ex4pmEngine.Wasm.Adapter` macro
  already carries once; these tests confirm each concrete module wires
  its own algorithm_id/engine_id/export names correctly.
  """

  use ExUnit.Case, async: true

  alias Ex4pmEngine.Wasm.{Align, EtcPrecision, OcDiscover, Playout, PrologQuery, Soundness}

  defp response_for(module, algorithm_id, result) do
    %{
      "standing" => "ALIVE",
      "result" => result,
      "receipt" => %{
        "schema" => module.protocol(),
        "algorithm_id" => to_string(algorithm_id),
        "wasm_export" => module.wasm_export(),
        "wasm4pm_source_sha" => module.wasm4pm_source_sha(),
        "request_digest" => "request-digest",
        "result_digest" => "result-digest"
      }
    }
  end

  defp exact_identity(module) do
    %{
      observed: true,
      wasm4pm_source_sha: module.wasm4pm_source_sha(),
      wasm_sha256: "sha256:observed-wasm",
      replay_verified: true
    }
  end

  test "align: id/supports?/alive path" do
    assert Align.id() == :wasm_align
    assert Align.supports?(:align, [])

    subject = %{
      traces: [["a", "b"]],
      petri_net: %{},
      sync_cost: 0.0,
      log_move_cost: 1.0,
      model_move_cost: 1.0
    }

    result_body = %{"alignments" => [%{"cost" => 0.0}]}

    transport = fn _r, _o ->
      {:ok, response_for(Align, :align, result_body), exact_identity(Align)}
    end

    assert {:ok, result} = Align.execute(:align, subject, align_wasm_fun: transport)
    assert result.standing == :alive
    assert result.engine == :wasm_align
  end

  test "etc_precision: id/supports?/alive path" do
    assert EtcPrecision.id() == :wasm_etc_precision
    assert EtcPrecision.supports?(:etc_precision, [])

    subject = %{net: %{}, initial_marking: %{}, final_marking: %{}, log: %{}, activity_key: "a"}
    result_body = %{"precision" => 1.0}

    transport = fn _r, _o ->
      {:ok, response_for(EtcPrecision, :etc_precision, result_body), exact_identity(EtcPrecision)}
    end

    assert {:ok, result} =
             EtcPrecision.execute(:etc_precision, subject, etc_precision_wasm_fun: transport)

    assert result.standing == :alive
    assert result.engine == :wasm_etc_precision
  end

  test "soundness: id/supports?/alive path" do
    assert Soundness.id() == :wasm_soundness
    assert Soundness.supports?(:soundness, [])

    subject = %{petri_net: %{}}
    result_body = %{"is_sound" => true}

    transport = fn _r, _o ->
      {:ok, response_for(Soundness, :soundness, result_body), exact_identity(Soundness)}
    end

    assert {:ok, result} = Soundness.execute(:soundness, subject, soundness_wasm_fun: transport)
    assert result.standing == :alive
    assert result.engine == :wasm_soundness
  end

  test "playout: id/supports?/alive path" do
    assert Playout.id() == :wasm_playout
    assert Playout.supports?(:playout, [])

    subject = %{petri_net: %{}, config: %{max_trace_length: 10, num_traces: 1, random_seed: 1}}
    result_body = %{"traces" => [], "all_complete" => true}

    transport = fn _r, _o ->
      {:ok, response_for(Playout, :playout, result_body), exact_identity(Playout)}
    end

    assert {:ok, result} = Playout.execute(:playout, subject, playout_wasm_fun: transport)
    assert result.standing == :alive
    assert result.engine == :wasm_playout
  end

  test "oc_discover: id/supports?/alive path" do
    assert OcDiscover.id() == :wasm_oc_discover
    assert OcDiscover.supports?(:oc_discover, [])

    subject = %{ocel: %{}, algorithm: "alpha++"}
    result_body = %{"nets" => []}

    transport = fn _r, _o ->
      {:ok, response_for(OcDiscover, :oc_discover, result_body), exact_identity(OcDiscover)}
    end

    assert {:ok, result} =
             OcDiscover.execute(:oc_discover, subject, oc_discover_wasm_fun: transport)

    assert result.standing == :alive
    assert result.engine == :wasm_oc_discover
  end

  test "prolog_query: id/supports?/alive path" do
    assert PrologQuery.id() == :wasm_prolog_query
    assert PrologQuery.supports?(:prolog_query, [])

    subject = %{
      predicates: [%{name: "parent", arity: 2}],
      facts: [%{pred: "parent", args: ["alice", "bob"]}],
      rules: [],
      query: %{pred: "parent", args: ["alice", "Y"]}
    }

    result_body = %{"result" => "answered", "answers" => [%{"bindings" => %{"Y" => "bob"}}]}

    transport = fn _r, _o ->
      {:ok, response_for(PrologQuery, :prolog_query, result_body), exact_identity(PrologQuery)}
    end

    assert {:ok, result} =
             PrologQuery.execute(:prolog_query, subject, prolog_query_wasm_fun: transport)

    assert result.standing == :alive
    assert result.engine == :wasm_prolog_query
  end
end
