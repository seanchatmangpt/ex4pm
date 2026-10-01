defmodule Ex4pm.GallCourtRepairTest do
  @moduledoc """
  Falsifiers for the second PR #47 court round (v26.9.26): identity
  collisions, portability of compute receipts, cost evidence, OCPQ query
  typing and event identity, and nested-choice ordering. Chicago style:
  real modules, real data, state-based assertions only.
  """
  use ExUnit.Case, async: true

  alias Ex4pm.Gall
  alias Ex4pm.Gall.{Compliance, Compute, Corpus, Ocpq, Portable, Powl}

  @sha "5abf57f91e85628a605a1dacace2a50e43fabb8b"

  defp attrs do
    [
      repository: "seanchatmangpt/ex4pm",
      producer_sha: @sha,
      corpus_digest: Corpus.manifest_digest()
    ]
  end

  defp rows do
    for i <- 1..20 do
      risky = rem(i, 4) == 0

      %{
        subject_id: "s#{String.pad_leading(Integer.to_string(i), 2, "0")}",
        label: if(risky, do: :deviation, else: :conformant),
        features: %{channel: if(risky, do: "manual", else: "api")}
      }
    end
  end

  describe "type-faithful identity (atom vs string keys never collide)" do
    test "typed_digest separates what digest/1 conflates" do
      assert Gall.digest(%{a: 1}) == Gall.digest(%{"a" => 1})
      refute Gall.typed_digest(%{a: 1}) == Gall.typed_digest(%{"a" => 1})
      refute Gall.typed_digest({"a", 1}) == Gall.typed_digest(["a", 1])
      assert Gall.typed_digest(%{a: 1, b: 2}) == Gall.typed_digest(%{b: 2, a: 1})
    end

    test "a selection re-keyed from atoms to strings is refused, not executed" do
      {:ok, model} = Compliance.train(rows(), kind: :one_rule)

      {:ok, selection} =
        Compute.select(:compliance_predict, %{
          model: model,
          subject_id: "x",
          features: %{channel: "manual"}
        })

      {:ok, honest} = Compute.execute(selection)
      assert honest.result.predicted_label == :deviation

      retargeted = %{selection | input: %{selection.input | features: %{"channel" => "manual"}}}
      assert {:error, :selection_digest_mismatch} = Compute.execute(retargeted)
    end

    test "a model whose table rows were re-keyed to strings is refused, never raises" do
      {:ok, model} = Compliance.train(rows(), kind: :one_rule)

      forged = %{
        model
        | table: Enum.map(model.table, fn r -> Map.new(r, fn {k, v} -> {to_string(k), v} end) end)
      }

      assert {:error, :model_digest_mismatch} = Compliance.predict(forged, "x", %{channel: "api"})

      {:ok, selection} =
        Compute.select(:compliance_predict, %{model: forged, subject_id: "x", features: %{}})

      assert {:error, :model_digest_mismatch} = Compute.execute(selection)
    end
  end

  describe "GALL-020 receipts are portable and carry cost evidence" do
    test "non-portable input is refused before compute, with a typed reason" do
      {:ok, float_sel} =
        Compute.select(:discover, %{traces: [["a", "b"]], rules: [{:require_edge, "a", 1.5}]})

      assert {:error, {:non_portable_compute, :input, {:float_not_in_portable_subset, 1.5}}} =
               Compute.execute(float_sel)

      {:ok, unicode_sel} = Compute.select(:powl_semantic, %{type: :task, id: "é"})

      assert {:error, {:non_portable_compute, :input, {:non_ascii_portable_value, :string, "é"}}} =
               Compute.execute(unicode_sel)

      {:ok, colliding} =
        Compute.select(:ocpq, %{
          ocel: %{events: []},
          query: %{"activity" => "a", activity: "a"}
        })

      assert {:error,
              {:non_portable_compute, :input, {:duplicate_object_key_after_stringification, _}}} =
               Compute.execute(colliding)
    end

    test "every OCEL receipt that executes crosses the Portable envelope" do
      ocel = Corpus.fixture!("object-centric").ocel
      {:ok, selection} = Compute.select(:ocpq, %{ocel: ocel, query: %{activity: "ship"}})
      {:ok, receipt} = Compute.execute(selection)
      assert {:ok, artifact} = Portable.build(:compute, receipt, attrs())
      assert {:ok, _} = Portable.verify(artifact |> Jason.encode!() |> Jason.decode!())
    end

    test "cost is deterministic, reflects input size and is bound into receipt identity" do
      small = %{traces: [["a", "b"]], rules: []}
      large = %{traces: List.duplicate(["a", "b"], 50), rules: []}

      {:ok, s1} = Compute.select(:discover, small)
      {:ok, r1} = Compute.execute(s1)
      {:ok, r1b} = Compute.execute(s1)
      {:ok, s2} = Compute.select(:discover, large)
      {:ok, r2} = Compute.execute(s2)

      assert r1 == r1b
      assert r1.cost.input_bytes == byte_size(Portable.canonical_json(small))
      assert r1.cost.result_bytes == byte_size(Portable.canonical_json(r1.result))
      assert r2.cost.input_bytes > r1.cost.input_bytes

      recomputed =
        Gall.digest(
          Map.take(r1, [:capability, :algorithm_version, :selection_digest, :result_digest, :cost])
        )

      assert r1.receipt_digest == recomputed

      forged_cost = put_in(r1, [:cost, :input_bytes], 0)

      refute Gall.digest(
               Map.take(forged_cost, [
                 :capability,
                 :algorithm_version,
                 :selection_digest,
                 :result_digest,
                 :cost
               ])
             ) == r1.receipt_digest
    end
  end

  describe "GALL-017 OCPQ query typing and event identity" do
    test "a non-boolean require_match is refused instead of becoming a vacuous pass" do
      ocel = %{events: [%{id: "e1", activity: "create", sequence: 1, objects: []}]}

      for value <- [nil, "false", 0] do
        assert {:error, {:invalid_ocpq_require_match, ^value}} =
                 Ocpq.evaluate(ocel, %{activity: "ship", require_match: value})
      end

      assert {:ok, %{standing: :pass, bindings: []}} =
               Ocpq.evaluate(ocel, %{activity: "ship", require_match: false})

      assert {:ok, %{standing: :violation}} =
               Ocpq.evaluate(ocel, %{activity: "ship", require_match: true})
    end

    test "two different events under one id are refused; identical re-delivery stays visible" do
      e = %{id: "e1", activity: "ship", sequence: 1, objects: [{"o1", "order", "t"}]}

      assert {:error, {:conflicting_ocel_event_id, "e1"}} =
               Ocpq.evaluate(%{events: [e, %{e | sequence: 2}]}, %{activity: "ship"})

      assert {:ok, %{bindings: [_, _]}} = Ocpq.evaluate(%{events: [e, e]}, %{activity: "ship"})
    end
  end

  describe "GALL-016 nested constructs" do
    test "a sequence over a choice never orders the exclusive branches" do
      {:ok, model} =
        Powl.from_semantic(%{
          type: :sequence,
          children: [%{type: :choice, children: ["a", "b"]}, "c"]
        })

      relations = Powl.semantic_properties(model).relations
      refute {"a", "b"} in relations
      refute {"b", "a"} in relations
      assert {"a", "c"} in relations
      assert {"b", "c"} in relations
    end

    test "unsound nets are refused; a sound choice and a loop reduce" do
      deadlock = %{
        transitions: ["a", "b", "c"],
        flow: [{"i", "a"}, {"i", "b"}, {"a", "q1"}, {"b", "q2"}, {"q1", "c"}, {"q2", "c"}]
      }

      nosync = %{
        transitions: ["s", "a", "b", "e"],
        flow: [
          {"s", "p1"},
          {"s", "p2"},
          {"p1", "a"},
          {"p2", "b"},
          {"a", "q"},
          {"b", "q"},
          {"q", "e"}
        ]
      }

      loop = %{
        transitions: ["s", "a", "b", "c"],
        flow: [{"s", "p"}, {"p", "a"}, {"a", "q"}, {"q", "b"}, {"b", "p"}, {"q", "c"}]
      }

      assert {:error, _} = Powl.from_wfnet(deadlock)
      assert {:error, _} = Powl.from_wfnet(nosync)
      assert {:ok, l} = Powl.from_wfnet(loop)

      assert Powl.structure(l) ==
               {:sequence, [{:task, "s"}, {:loop, {:task, "a"}, {:task, "b"}}, {:task, "c"}]}
    end
  end
end
