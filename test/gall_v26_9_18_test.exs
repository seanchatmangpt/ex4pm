defmodule Ex4pm.GallTest do
  use ExUnit.Case, async: true

  alias Ex4pm.Gall
  alias Ex4pm.Gall.{Compliance, Compute, Corpus, Discovery, Ocpq, Portable, Powl}

  test "GALL-015 corpus is content-addressed and includes positive/negative process classes" do
    manifest = Corpus.manifest()
    assert length(manifest.fixture_ids) >= 7
    assert "parallel" in manifest.fixture_ids
    assert "object-centric" in manifest.fixture_ids
    assert "invalid-order-cycle" in manifest.fixture_ids
    assert String.starts_with?(Corpus.manifest_digest(), "sha256:")
  end

  test "GALL-016 semantic and WF-net ingress preserve the same sequence relations" do
    {:ok, semantic} =
      Powl.from_semantic(%{type: :sequence, children: ["a", "b", "c"]})

    {:ok, wfnet} =
      Powl.from_wfnet(%{
        transitions: ["a", "b", "c"],
        flow: [{"a", "b"}, {"b", "c"}]
      })

    semantic_properties = Powl.semantic_properties(semantic)
    wfnet_properties = Powl.semantic_properties(wfnet)

    assert semantic_properties.tasks == wfnet_properties.tasks
    assert semantic_properties.relations == wfnet_properties.relations

    invalid = Corpus.fixture!("invalid-order-cycle")
    assert {:error, :cyclic_partial_order} = Powl.from_semantic(invalid.semantic)
  end

  test "GALL-016 hierarchy is retained rather than flattened" do
    fixture = Corpus.fixture!("hierarchy")
    assert {:ok, receipt} = Powl.from_semantic(fixture.semantic)
    assert receipt.model.type == :hierarchy
    assert receipt.model.id == "parent"
    assert Powl.semantic_properties(receipt).hierarchy == ["parent"]
  end

  test "GALL-017 OCPQ returns deterministic multi-object binding and temporal relation" do
    fixture = Corpus.fixture!("object-centric")

    query = %{
      activity: "ship",
      object_type: "item",
      qualifier: "contains",
      after_activity: "create"
    }

    assert {:ok, result} = Ocpq.evaluate(fixture.ocel, query)
    assert result.standing == :pass
    assert [%{event_id: "e2", objects: objects}] = result.bindings
    assert {"item:1", "item", "contains"} in objects

    permuted = %{events: Enum.reverse(fixture.ocel.events)}
    assert {:ok, same} = Ocpq.evaluate(permuted, query)
    assert same.result_digest == result.result_digest

    assert {:ok, missing} =
             Ocpq.evaluate(fixture.ocel, %{activity: "never", require_match: true})

    assert missing.standing == :violation
    assert [%{type: :missing_required_binding}] = missing.violations
  end

  test "GALL-018 normative rules constrain discovery without being rewritten" do
    traces = [["a", "b", "c"], ["a", "b", "c"]]

    assert {:ok, lawful} =
             Discovery.discover(traces, [{:before, "a", "c"}, {:require_edge, "a", "b"}])

    assert lawful.standing == :candidate
    assert length(lawful.candidates) == 1
    assert lawful.deviations == []

    assert {:ok, blocked} =
             Discovery.discover(traces, [{:forbid_edge, "a", "b"}])

    assert blocked.standing == :blocked
    assert blocked.candidates == []
    assert [%{type: :forbidden_edge_observed}] = blocked.deviations
  end

  test "GALL-019 compliance baseline is subject-split and candidate-only" do
    rows =
      for {subject, label} <- [
            {"a", :conformant},
            {"b", :conformant},
            {"c", :deviation},
            {"d", :conformant},
            {"e", :deviation}
          ] do
        %{subject_id: subject, label: label, feature: String.length(subject)}
      end

    assert {:ok, train, validation, test_rows} = Compliance.split_by_subject(rows)
    train_ids = MapSet.new(Enum.map(train, & &1.subject_id))
    validation_ids = MapSet.new(Enum.map(validation, & &1.subject_id))
    test_ids = MapSet.new(Enum.map(test_rows, & &1.subject_id))
    assert MapSet.disjoint?(train_ids, validation_ids)
    assert MapSet.disjoint?(train_ids, test_ids)
    assert MapSet.disjoint?(validation_ids, test_ids)

    {:ok, model} = Compliance.train(train)
    {:ok, prediction} = Compliance.predict(model, "held-out", %{x: 1})
    assert prediction.standing == :candidate
    assert String.starts_with?(prediction.model_digest, "sha256:")
  end

  test "GALL-020 selects computation but deterministic algorithm owns result" do
    input = %{type: :sequence, children: ["a", "b"]}

    assert {:ok, selection} = Compute.select(:powl_semantic, input)
    assert selection.authority == :none
    assert {:ok, receipt} = Compute.execute(selection)
    assert receipt.model_required == false
    assert receipt.capability == :powl_semantic
    assert String.starts_with?(receipt.result_digest, "sha256:")

    assert {:error, :refused_model_authored_computation_result} =
             Compute.execute_model_authored_result(%{answer: "looks right"})

    assert {:error, {:unsupported_process_capability, :unknown}} =
             Compute.select(:unknown, %{})
  end

  test "canonical digest is invariant to map insertion order" do
    assert Gall.digest(%{a: 1, b: 2}) == Gall.digest(%{b: 2, a: 1})
  end

  test "portable artifact survives JSON transport and fails closed on tampering" do
    assert {:ok, powl} =
             Powl.from_semantic(%{
               type: :partial_order,
               children: ["a", "b"],
               order: []
             })

    assert {:ok, artifact} =
             Portable.build(:powl, powl,
               repository: "seanchatmangpt/ex4pm",
               producer_sha: "5abf57f91e85628a605a1dacace2a50e43fabb8b",
               corpus_digest: Corpus.manifest_digest(),
               evidence_class: "normative-process-law"
             )

    assert artifact["authority"] == "NONE"
    assert String.starts_with?(artifact["payload_digest"], "sha256:")
    assert String.starts_with?(artifact["artifact_digest"], "sha256:")
    assert {:ok, ^artifact} = Portable.verify(artifact)

    transported = artifact |> Jason.encode!() |> Jason.decode!()
    assert {:ok, ^transported} = Portable.verify(transported)

    tampered = put_in(transported, ["payload", "model", "type"], "sequence")
    assert {:error, :payload_digest_mismatch} = Portable.verify(tampered)

    assert Portable.digest(%{"b" => 2, "a" => 1}) ==
             Portable.digest(%{"a" => 1, "b" => 2})

    assert artifact["canonicalization"] == "RFC8785/JCS-IJSON-ASCII-INTEGER-SUBSET"

    assert {:error, {:float_not_in_portable_subset, 0.5}} =
             Portable.build(:powl, %{"threshold" => 0.5},
               repository: "seanchatmangpt/ex4pm",
               producer_sha: "5abf57f91e85628a605a1dacace2a50e43fabb8b",
               corpus_digest: Corpus.manifest_digest()
             )
  end

  test "portable artifact rejects unbound producer identity" do
    assert {:error, {:invalid_producer_sha, "main"}} =
             Portable.build(:powl, %{},
               repository: "seanchatmangpt/ex4pm",
               producer_sha: "main",
               corpus_digest: Corpus.manifest_digest()
             )
  end
end
