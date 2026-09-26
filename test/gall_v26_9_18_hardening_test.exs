defmodule Ex4pm.GallHardeningTest do
  @moduledoc """
  Boundary, negative and adversarial falsifiers for the GALL v26.9.18
  process-law surfaces (GALL-015..020) and the portable envelope.

  Chicago style: every collaborator is real. The JCS differential runs the
  real `node` binary (ECMAScript JSON.stringify is the RFC 8785 string and
  integer serializer) and is a named skip only when node is absent.
  """
  use ExUnit.Case, async: true

  alias Ex4pm.Gall.{Compliance, Compute, Corpus, Discovery, Ocpq, Portable, Powl}

  @sha "5abf57f91e85628a605a1dacace2a50e43fabb8b"
  @other_sha "0123456789abcdef0123456789abcdef01234567"

  defp attrs(extra \\ []) do
    Keyword.merge(
      [
        repository: "seanchatmangpt/ex4pm",
        producer_sha: @sha,
        corpus_digest: Corpus.manifest_digest()
      ],
      extra
    )
  end

  defp artifact! do
    {:ok, powl} = Powl.from_semantic(%{type: :sequence, children: ["a", "b", "c"]})
    {:ok, artifact} = Portable.build(:powl, powl, attrs())
    artifact
  end

  defp redigest(artifact) do
    body = Map.delete(artifact, "artifact_digest")
    Map.put(body, "artifact_digest", Portable.digest(body))
  end

  describe "portable envelope: JCS canonical form" do
    test "C0 controls use lowercase \\u00xx escapes; slash and DEL are verbatim" do
      assert Portable.canonical_json(<<0x1F>>) == ~S("\u001f")
      assert Portable.canonical_json(<<0x01, 0x0B, 0x0E>>) == ~S("\u0001\u000b\u000e")
      assert Portable.canonical_json("\b\t\n\f\r") == ~S("\b\t\n\f\r")
      assert Portable.canonical_json("a/b" <> <<0x7F>>) == "\"a/b" <> <<0x7F>> <> "\""
      assert Portable.canonical_json("q\"\\") == ~S|"q\"\\"|
    end

    @node System.find_executable("node")
    if is_nil(@node), do: @tag(skip: "node absent: ECMAScript JCS reference unavailable")

    test "differential: canonical_json equals node JSON.stringify with sorted keys" do
      control = for b <- 0..0x1F, into: "", do: <<b>>

      values = [
        %{"z" => 1, "a" => [true, false, nil], "m" => %{"y" => -9_007_199_254_740_991}},
        %{"s" => control <> "/\"\\" <> <<0x7F>> <> "~ !"},
        [9_007_199_254_740_991, 0, -1, "", %{}],
        %{"B" => 1, "a" => 2, "_" => 3, "A" => 4, "0" => 5}
      ]

      script = """
      const sort = v => Array.isArray(v) ? v.map(sort)
        : (v && typeof v === 'object')
          ? Object.fromEntries(Object.keys(v).sort().map(k => [k, sort(v[k])]))
          : v;
      let s = '';
      process.stdin.on('data', d => s += d);
      process.stdin.on('end', () => {
        for (const line of s.split('\\n').filter(Boolean)) {
          process.stdout.write(JSON.stringify(sort(JSON.parse(line))) + '\\n');
        }
      });
      """

      input = Enum.map_join(values, "\n", &Jason.encode!/1) <> "\n"
      path = Path.join(System.tmp_dir!(), "gall-jcs-#{System.unique_integer([:positive])}.json")
      File.write!(path, input)

      {out, 0} = System.cmd("sh", ["-c", "node -e \"$0\" < \"$1\"", script, path])
      File.rm!(path)

      assert String.split(out, "\n", trim: true) == Enum.map(values, &Portable.canonical_json/1)
    end
  end

  describe "portable envelope: refusal of non-portable input" do
    test "invalid UTF-8 and non-ASCII strings are refused, not raised" do
      assert {:error, {:non_ascii_portable_value, :string, <<0xFF>>}} =
               Portable.build(:powl, %{"x" => <<0xFF>>}, attrs())

      assert {:error, {:non_ascii_portable_value, :object_key, "é"}} =
               Portable.build(:powl, %{"é" => 1}, attrs())
    end

    test "distinct keys colliding after stringification are refused, not merged" do
      assert {:error, {:duplicate_object_key_after_stringification, {"a", _}}} =
               Portable.build(:powl, %{:a => 1, "a" => 2}, attrs())

      assert {:error, {:duplicate_object_key_after_stringification, {"1", _}}} =
               Portable.build(:powl, %{1 => :x, "1" => :y}, attrs())

      assert_raise ArgumentError, ~r/duplicate_object_key/, fn ->
        Portable.digest(%{:k => 1, "k" => 1})
      end
    end

    test "I-JSON exact integer range is the boundary" do
      assert {:ok, _} = Portable.build(:powl, %{"n" => 9_007_199_254_740_991}, attrs())
      assert {:ok, _} = Portable.build(:powl, %{"n" => -9_007_199_254_740_991}, attrs())

      assert {:error, {:integer_outside_ijson_exact_range, 9_007_199_254_740_992}} =
               Portable.build(:powl, %{"n" => 9_007_199_254_740_992}, attrs())
    end

    test "non-string object keys, structs and pids are refused" do
      assert {:error, {:non_string_object_key, {:t}}} =
               Portable.build(:powl, %{{:t} => 1}, attrs())

      assert {:error, {:unsupported_json_value, _}} =
               Portable.build(:powl, %{"d" => ~D[2026-09-26]}, attrs())

      assert {:error, {:unsupported_json_value, _}} =
               Portable.build(:powl, %{"p" => self()}, attrs())
    end

    test "non-ASCII kind or evidence class is refused instead of crashing the digest" do
      assert {:error, {:non_ascii_portable_value, :string, "é"}} =
               Portable.build("é", %{}, attrs())

      assert {:error, {:non_ascii_portable_value, :string, "é"}} =
               Portable.build(:powl, %{}, attrs(evidence_class: "é"))
    end

    test "unbound producer identity and malformed digests are refused" do
      assert {:error, {:invalid_producer_sha, "HEAD"}} =
               Portable.build(:powl, %{}, attrs(producer_sha: "HEAD"))

      assert {:error, {:invalid_producer_sha, _}} =
               Portable.build(:powl, %{}, attrs(producer_sha: String.upcase(@sha)))

      assert {:error, {:invalid_repository, "ex4pm"}} =
               Portable.build(:powl, %{}, attrs(repository: "ex4pm"))

      assert {:error, {:invalid_repository, "a/b/c"}} =
               Portable.build(:powl, %{}, attrs(repository: "a/b/c"))

      assert {:error, {:invalid_digest, :corpus_digest, "sha256:abc"}} =
               Portable.build(:powl, %{}, attrs(corpus_digest: "sha256:abc"))
    end
  end

  describe "portable envelope: verify fails closed" do
    test "duplicate delivery and key reordering replay to the identical artifact" do
      artifact = artifact!()
      assert {:ok, ^artifact} = Portable.verify(artifact)
      assert {:ok, ^artifact} = Portable.verify(artifact)

      reordered =
        artifact
        |> Enum.reverse()
        |> Enum.map_join(",", fn {k, v} -> Jason.encode!(k) <> ":" <> Jason.encode!(v) end)
        |> then(&("{" <> &1 <> "}"))
        |> Jason.decode!()

      assert {:ok, ^artifact} = Portable.verify(reordered)
    end

    test "stale producer subject is detected even when every field stays well-formed" do
      stale = put_in(artifact!(), ["producer", "sha"], @other_sha)
      assert {:error, :artifact_digest_mismatch} = Portable.verify(stale)
    end

    test "wrong corpus digest, injected field and swapped payload digest are detected" do
      artifact = artifact!()

      assert {:error, :artifact_digest_mismatch} =
               Portable.verify(
                 Map.put(artifact, "corpus_digest", "sha256:" <> String.duplicate("0", 64))
               )

      assert {:error, :artifact_digest_mismatch} =
               Portable.verify(Map.put(artifact, "note", "injected"))

      forged_payload = put_in(artifact, ["payload", "model", "type"], "choice")
      assert {:error, :payload_digest_mismatch} = Portable.verify(forged_payload)

      # A forger who recomputes the envelope digest but not the payload digest
      assert {:error, :payload_digest_mismatch} = Portable.verify(redigest(forged_payload))
    end

    test "expanded authority and schema drift are typed refusals, even when re-digested" do
      artifact = artifact!()

      assert {:error, {:authority_expanded, "DO"}} =
               Portable.verify(redigest(Map.put(artifact, "authority", "DO")))

      assert {:error, {:authority_expanded, nil}} =
               Portable.verify(redigest(Map.delete(artifact, "authority")))

      assert {:error, {:identity_mismatch, :schema, _, "ex4pm.gall.portable/v0"}} =
               Portable.verify(redigest(Map.put(artifact, "schema", "ex4pm.gall.portable/v0")))

      assert {:error, {:identity_mismatch, :canonicalization, _, "JSON"}} =
               Portable.verify(redigest(Map.put(artifact, "canonicalization", "JSON")))

      assert {:error, :producer_missing} = Portable.verify(Map.delete(artifact, "producer"))
    end

    test "non-portable values anywhere in the envelope are refused, not raised" do
      artifact = artifact!()

      assert {:error, {:float_not_in_portable_subset, 0.5}} =
               Portable.verify(Map.put(artifact, "evidence_class", 0.5))

      assert {:error, {:non_ascii_portable_value, :string, <<0xFE>>}} =
               Portable.verify(Map.put(artifact, "kind", <<0xFE>>))

      assert {:error, :invalid_portable_artifact} = Portable.verify(["not", "a", "map"])
    end
  end

  describe "GALL-016 POWL ingress boundaries" do
    test "WF-net arcs routed through places preserve the transition order" do
      {:ok, semantic} = Powl.from_semantic(%{type: :sequence, children: ["a", "b", "c"]})

      {:ok, wfnet} =
        Powl.from_wfnet(%{
          transitions: ["a", "b", "c"],
          flow: [{"i", "a"}, {"a", "p1"}, {"p1", "b"}, {"b", "p2"}, {"p2", "c"}, {"c", "o"}]
        })

      assert Powl.semantic_properties(wfnet).relations ==
               Powl.semantic_properties(semantic).relations

      assert Powl.semantic_properties(wfnet).relations == [{"a", "b"}, {"a", "c"}, {"b", "c"}]
    end

    test "WF-net loop through a place is refused as a cyclic order" do
      assert {:error, :cyclic_partial_order} =
               Powl.from_wfnet(%{
                 transitions: ["a", "b"],
                 flow: [{"a", "p"}, {"p", "b"}, {"b", "q"}, {"q", "a"}]
               })
    end

    test "duplicate transitions and malformed arcs are refused" do
      assert {:error, {:duplicate_wfnet_transition, "a"}} =
               Powl.from_wfnet(%{transitions: ["a", "a"], flow: []})

      assert {:error, {:invalid_wfnet_arc, {"a", "b", "c"}}} =
               Powl.from_wfnet(%{transitions: ["a", "b"], flow: [{"a", "b", "c"}]})

      assert {:error, :invalid_wfnet} = Powl.from_wfnet(%{transitions: [], flow: []})
      assert {:error, :invalid_wfnet} = Powl.from_wfnet("net")
    end

    test "a cyclic partial order nested under another construct is refused" do
      cyclic = %{type: :partial_order, children: ["a", "b"], order: [{"a", "b"}, {"b", "a"}]}

      assert {:error, :cyclic_partial_order} =
               Powl.from_semantic(%{type: :sequence, children: ["x", cyclic]})

      assert {:error, :cyclic_partial_order} =
               Powl.from_semantic(%{type: :hierarchy, id: "h", child: cyclic})

      assert {:error, :cyclic_partial_order} =
               Powl.from_semantic(%{type: :loop, body: cyclic, redo: "r"})

      assert {:error, :cyclic_partial_order} =
               Powl.from_semantic(%{type: :partial_order, children: ["x", cyclic], order: []})
    end

    test "malformed order edges, unknown tasks and unsupported constructs are refused" do
      assert {:error, {:invalid_partial_order_edge, {"a"}}} =
               Powl.from_semantic(%{type: :partial_order, children: ["a"], order: [{"a"}]})

      assert {:error, :partial_order_unknown_task} =
               Powl.from_semantic(%{type: :partial_order, children: ["a"], order: [{"a", "z"}]})

      assert {:error, {:unsupported_powl_construct, :xor_join}} =
               Powl.from_semantic(%{type: :xor_join, children: ["a"]})

      assert {:error, :empty_children} = Powl.from_semantic(%{type: :sequence, children: []})
    end
  end

  describe "GALL-017 OCPQ boundaries" do
    test "malformed events and unsupported operators are refused" do
      assert {:error, {:invalid_ocel_event, %{activity: "x"}}} =
               Ocpq.evaluate(%{events: [%{activity: "x"}]}, %{activity: "x"})

      assert {:error, {:invalid_ocel_event, _}} =
               Ocpq.evaluate(%{events: [%{id: "e", objects: [{"o", "t"}]}]}, %{})

      assert {:error, {:unsupported_ocpq_operator, "activity"}} =
               Ocpq.evaluate(%{events: []}, %{"activity" => "x"})

      assert {:error, :invalid_ocel} = Ocpq.evaluate(%{}, %{})
    end

    test "temporal relation is strict and independent of event delivery order" do
      events = [
        %{id: "e1", activity: "create", sequence: 1, objects: []},
        %{id: "e2", activity: "ship", sequence: 1, objects: []}
      ]

      query = %{activity: "ship", after_activity: "create"}

      assert {:ok, %{standing: :violation, bindings: []}} =
               Ocpq.evaluate(%{events: events}, query)

      duplicated = %{events: events ++ events}
      {:ok, once} = Ocpq.evaluate(%{events: events}, %{activity: "ship"})
      {:ok, twice} = Ocpq.evaluate(duplicated, %{activity: "ship"})
      # Duplicate delivery is visible in the result (not silently deduplicated)
      assert length(twice.bindings) == 2 * length(once.bindings)
      assert once.result_digest != twice.result_digest
    end
  end

  describe "GALL-018 discovery boundaries" do
    test "malformed traces are refused with a typed error" do
      assert {:error, {:invalid_trace, "abc"}} = Discovery.discover(["abc"], [])
      assert {:error, {:invalid_trace, [:a]}} = Discovery.discover([[:a]], [])
      assert {:error, :invalid_discovery_input} = Discovery.discover(%{}, [])
    end

    test "unsupported rules block instead of being ignored" do
      assert {:ok,
              %{standing: :blocked, candidates: [], deviations: [%{type: :unsupported_rule}]}} =
               Discovery.discover([["a", "b"]], [{:eventually, "a", "b"}])
    end

    test "trace reordering changes observation digest but not the edge set" do
      traces = [["a", "b"], ["a", "c"]]
      {:ok, left} = Discovery.discover(traces, [])
      {:ok, right} = Discovery.discover(Enum.reverse(traces), [])
      [l] = left.candidates
      [r] = right.candidates
      assert l.edges == r.edges
      assert l.observation_digest != r.observation_digest
    end
  end

  describe "GALL-019 compliance boundaries" do
    test "prediction score is an integer share and portable across runtimes" do
      rows =
        for {s, l} <- [{"a", :ok}, {"b", :ok}, {"c", :bad}] do
          %{subject_id: s, label: l}
        end

      model = Compliance.train(rows)
      assert model.majority_label == :ok
      assert model.majority_share_bp == 6666
      prediction = Compliance.predict(model, "z", %{x: 1})
      assert prediction.score_bp == 6666
      assert {:ok, _} = Portable.build(:compliance_prediction, prediction, attrs())
    end

    test "fewer than three subjects is refused; subjects never straddle splits" do
      assert {:error, :insufficient_subjects} =
               Compliance.split_by_subject([%{subject_id: "a"}, %{subject_id: "b"}])

      rows = for s <- 1..17, n <- 1..3, do: %{subject_id: "s#{s}", label: rem(n, 2), n: n}
      {:ok, train, val, test_rows} = Compliance.split_by_subject(Enum.shuffle(rows))
      ids = fn rows -> rows |> Enum.map(& &1.subject_id) |> MapSet.new() end
      assert MapSet.disjoint?(ids.(train), ids.(val))
      assert MapSet.disjoint?(ids.(train), ids.(test_rows))
      assert MapSet.disjoint?(ids.(val), ids.(test_rows))
      assert length(train) + length(val) + length(test_rows) == length(rows)
      assert test_rows != []
    end
  end

  describe "GALL-020 dispatcher integrity" do
    test "a forged or re-targeted selection digest is refused" do
      {:ok, selection} = Compute.select(:powl_semantic, %{type: :sequence, children: ["a", "b"]})

      assert {:error, :selection_digest_mismatch} =
               Compute.execute(%{
                 selection
                 | selection_digest: "sha256:" <> String.duplicate("f", 64)
               })

      retargeted = %{selection | input: %{type: :sequence, children: ["b", "a"]}}
      assert {:error, :selection_digest_mismatch} = Compute.execute(retargeted)
    end

    test "authority expansion on a selection is refused" do
      {:ok, selection} = Compute.select(:powl_semantic, %{type: :task, id: "a"})
      assert {:error, {:authority_expanded, :do}} = Compute.execute(%{selection | authority: :do})
    end

    test "malformed capability input is a typed refusal, not a crash" do
      {:ok, selection} = Compute.select(:ocpq, %{ocel: %{events: []}})
      assert {:error, {:invalid_capability_input, :ocpq}} = Compute.execute(selection)

      {:ok, selection} =
        Compute.select(:compliance_predict, %{model: %{}, subject_id: "s", features: %{}})

      assert {:error, {:invalid_capability_input, :compliance_predict}} =
               Compute.execute(selection)

      assert {:error, :invalid_selection} = Compute.execute(%{capability: :ocpq})
      assert {:error, {:unsupported_process_capability, "ocpq"}} = Compute.select("ocpq", %{})
    end

    test "every capability receipt is replayable and crosses the portable envelope" do
      ocel = Corpus.fixture!("object-centric").ocel
      model = Compliance.train([%{subject_id: "a", label: :ok}, %{subject_id: "b", label: :bad}])

      inputs = %{
        powl_semantic: %{type: :sequence, children: ["a", "b"]},
        powl_wfnet: %{transitions: ["a", "b"], flow: [{"a", "p"}, {"p", "b"}]},
        ocpq: %{ocel: ocel, query: %{activity: "ship"}},
        discover: %{traces: [["a", "b"]], rules: [{:require_edge, "a", "b"}]},
        compliance_predict: %{model: model, subject_id: "c", features: %{k: 1}}
      }

      assert Map.keys(inputs) |> Enum.sort() ==
               Compute.capabilities() |> Map.keys() |> Enum.sort()

      for {capability, input} <- inputs do
        {:ok, selection} = Compute.select(capability, input)
        {:ok, receipt} = Compute.execute(selection)
        {:ok, replay} = Compute.execute(selection)
        assert receipt == replay, "replay mismatch for #{capability}"

        assert {:ok, artifact} = Portable.build(capability, receipt, attrs()),
               "receipt for #{capability} is not portable"

        assert {:ok, _} = Portable.verify(artifact |> Jason.encode!() |> Jason.decode!())
      end
    end
  end
end
