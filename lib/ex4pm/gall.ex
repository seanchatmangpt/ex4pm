defmodule Ex4pm.Gall do
  @moduledoc """
  v26.9.18 GALL process-law qualification surfaces.

  This namespace implements the reference semantics for GALL-015..020:
  corpus identity, POWL dual ingress, OCPQ reference evaluation,
  rule-constrained discovery, candidate-only compliance prediction, and a
  deterministic process-compute dispatcher. It does not actuate.
  """

  def digest(value) do
    "sha256:" <>
      (:crypto.hash(:sha256, :erlang.term_to_binary(canonical(value), [:deterministic]))
       |> Base.encode16(case: :lower))
  end

  def canonical(value) when is_map(value) do
    value
    |> Enum.map(fn {key, item} -> {to_string(key), canonical(item)} end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  def canonical(value) when is_list(value), do: Enum.map(value, &canonical/1)
  def canonical(value) when is_tuple(value), do: value |> Tuple.to_list() |> canonical()
  def canonical(value), do: value
end

defmodule Ex4pm.Gall.Portable do
  @moduledoc """
  Language-neutral GALL artifact envelope for cross-repository courts.

  Ex4pm.Gall.digest/1 intentionally remains the BEAM-local semantic digest.
  Cross-language consumers instead verify this envelope's canonical JSON
  SHA-256 so Rust/WASM/BEAM can independently recompute the same identity.

  Canonical form is RFC 8785 (JCS) restricted to a subset whose serialization
  is identical in every conforming runtime: ASCII strings and object names,
  booleans, null, arrays, objects, and integers exactly representable as
  IEEE-754 doubles. Strings are serialized by this module (not by Jason) so
  control characters use JCS's lowercase `\\u00xx` escapes.

  Every non-portable input is refused with a typed error: floats, integers
  outside the I-JSON exact range, non-ASCII or invalid-UTF-8 strings,
  non-string object keys, and distinct keys that collide once stringified
  (e.g. `:a` and `"a"`), which would otherwise be silently dropped.

  The envelope grants no authority and carries no execution standing.
  """

  @schema "ex4pm.gall.portable/v26.9.19"
  @canonicalization "RFC8785/JCS-IJSON-ASCII-INTEGER-SUBSET"
  @sha ~r/\A[0-9a-f]{40}\z/
  @digest ~r/\Asha256:[0-9a-f]{64}\z/

  @spec build(atom() | String.t(), term(), keyword() | map()) ::
          {:ok, map()} | {:error, term()}
  def build(kind, payload, attrs) do
    attrs = Map.new(attrs)
    repository = attrs[:repository] || attrs["repository"]
    producer_sha = attrs[:producer_sha] || attrs["producer_sha"]
    corpus_digest = attrs[:corpus_digest] || attrs["corpus_digest"]
    evidence_class = attrs[:evidence_class] || attrs["evidence_class"] || "process-law"

    with :ok <- repository(repository),
         :ok <- producer_sha(producer_sha),
         :ok <- digest_value(:corpus_digest, corpus_digest),
         {:ok, payload} <- normalize(payload),
         :ok <- jcs_subset(payload) do
      body = %{
        "schema" => @schema,
        "kind" => label(kind),
        "producer" => %{"repository" => repository, "sha" => producer_sha},
        "corpus_digest" => corpus_digest,
        "payload" => payload,
        "payload_digest" => digest(payload),
        "evidence_class" => label(evidence_class),
        "canonicalization" => @canonicalization,
        "authority" => "NONE"
      }

      with :ok <- jcs_subset(body) do
        {:ok, Map.put(body, "artifact_digest", digest(body))}
      end
    end
  end

  @spec verify(map()) :: {:ok, map()} | {:error, term()}
  def verify(artifact) when is_map(artifact) do
    with {:ok, artifact} <- normalize(artifact),
         :ok <- jcs_subset(artifact),
         :ok <- equal(:schema, artifact["schema"], @schema),
         :ok <- authority(artifact["authority"]),
         {:ok, repository, producer_sha} <- producer(artifact["producer"]),
         :ok <- repository(repository),
         :ok <- producer_sha(producer_sha),
         :ok <- digest_value(:corpus_digest, artifact["corpus_digest"]),
         :ok <- digest_value(:payload_digest, artifact["payload_digest"]),
         :ok <- digest_value(:artifact_digest, artifact["artifact_digest"]),
         :ok <- equal(:canonicalization, artifact["canonicalization"], @canonicalization),
         :ok <-
           matches(
             :payload_digest_mismatch,
             digest(artifact["payload"]),
             artifact["payload_digest"]
           ),
         :ok <-
           matches(
             :artifact_digest_mismatch,
             digest(Map.delete(artifact, "artifact_digest")),
             artifact["artifact_digest"]
           ) do
      {:ok, artifact}
    end
  end

  def verify(_), do: {:error, :invalid_portable_artifact}

  @spec digest(term()) :: String.t()
  def digest(value) do
    "sha256:" <> (:crypto.hash(:sha256, canonical_json(value)) |> Base.encode16(case: :lower))
  end

  @doc """
  Canonical JSON used by every portable GALL digest.

  Object keys are sorted lexicographically (byte order equals JCS UTF-16
  order on the ASCII subset); arrays preserve semantic order; tuples become
  arrays; non-boolean atoms become strings. Raises `ArgumentError` on any
  input outside the portable subset.
  """
  @spec canonical_json(term()) :: String.t()
  def canonical_json(value) do
    with {:ok, value} <- normalize(value),
         :ok <- jcs_subset(value) do
      canonical_jcs_subset(value)
    else
      {:error, reason} -> raise ArgumentError, "non-portable JCS input: #{inspect(reason)}"
    end
  end

  defp canonical_jcs_subset(value) when is_map(value) do
    entries =
      value
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map_join(",", fn {key, item} ->
        jcs_string(key) <> ":" <> canonical_jcs_subset(item)
      end)

    "{" <> entries <> "}"
  end

  defp canonical_jcs_subset(value) when is_list(value),
    do: "[" <> Enum.map_join(value, ",", &canonical_jcs_subset/1) <> "]"

  defp canonical_jcs_subset(true), do: "true"
  defp canonical_jcs_subset(false), do: "false"
  defp canonical_jcs_subset(nil), do: "null"
  defp canonical_jcs_subset(value) when is_binary(value), do: jcs_string(value)
  defp canonical_jcs_subset(value) when is_integer(value), do: Integer.to_string(value)

  # RFC 8785 section 3.2.2.2 (ECMAScript JSON.stringify string serialization)
  # restricted to ASCII: escape `"` and `\`, use the short escapes for
  # \b \t \n \f \r, lowercase `\u00xx` for the remaining C0 controls, and
  # emit every other byte (including `/` and DEL) verbatim.
  defp jcs_string(value) do
    if plain_ascii?(value) do
      "\"" <> value <> "\""
    else
      "\"" <> escape_ascii(value) <> "\""
    end
  end

  # Fast path: printable ASCII without `"` or `\\` needs no escaping.
  defp plain_ascii?(<<>>), do: true

  defp plain_ascii?(<<b, rest::binary>>) when b >= 0x20 and b != ?" and b != ?\\,
    do: plain_ascii?(rest)

  defp plain_ascii?(_), do: false

  defp escape_ascii(value) do
    for <<byte <- value>>, into: "" do
      case byte do
        ?" -> "\\\""
        ?\\ -> "\\\\"
        ?\b -> "\\b"
        ?\t -> "\\t"
        ?\n -> "\\n"
        ?\f -> "\\f"
        ?\r -> "\\r"
        b when b < 0x20 -> "\\u00" <> String.downcase(Base.encode16(<<b>>))
        b -> <<b>>
      end
    end
  end

  defp jcs_subset(value) when is_map(value) do
    Enum.reduce_while(value, :ok, fn
      {key, item}, :ok when is_binary(key) ->
        with :ok <- ascii(:object_key, key),
             :ok <- jcs_subset(item) do
          {:cont, :ok}
        else
          {:error, _} = error -> {:halt, error}
        end

      {key, _item}, :ok ->
        {:halt, {:error, {:non_string_object_key, key}}}
    end)
  end

  defp jcs_subset(value) when is_list(value) do
    Enum.reduce_while(value, :ok, fn item, :ok ->
      case jcs_subset(item) do
        :ok -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp jcs_subset(value) when is_binary(value), do: ascii(:string, value)
  defp jcs_subset(value) when is_integer(value) and abs(value) <= 9_007_199_254_740_991, do: :ok

  defp jcs_subset(value) when is_integer(value),
    do: {:error, {:integer_outside_ijson_exact_range, value}}

  defp jcs_subset(value) when is_float(value),
    do: {:error, {:float_not_in_portable_subset, value}}

  defp jcs_subset(value) when value in [true, false, nil], do: :ok
  defp jcs_subset(value), do: {:error, {:unsupported_json_value, value}}

  # Byte-level check: never raises on invalid UTF-8 (String.to_charlist does).
  defp ascii(field, value) when is_binary(value) do
    if ascii_bytes?(value), do: :ok, else: {:error, {:non_ascii_portable_value, field, value}}
  end

  defp ascii_bytes?(<<>>), do: true
  defp ascii_bytes?(<<b, rest::binary>>) when b <= 0x7F, do: ascii_bytes?(rest)
  defp ascii_bytes?(_), do: false

  defp equal(_field, value, value), do: :ok
  defp equal(field, actual, expected), do: {:error, {:identity_mismatch, field, expected, actual}}

  defp matches(_reason, value, value), do: :ok
  defp matches(reason, _actual, _expected), do: {:error, reason}

  defp authority("NONE"), do: :ok
  defp authority(other), do: {:error, {:authority_expanded, other}}

  defp producer(%{"repository" => repository, "sha" => sha}), do: {:ok, repository, sha}
  defp producer(_), do: {:error, :producer_missing}

  defp label(value) when is_atom(value) and value not in [nil, true, false],
    do: Atom.to_string(value)

  defp label(value), do: value

  @doc false
  # Converts an Elixir term into the JSON data model, refusing (instead of
  # silently merging) distinct keys that stringify to the same object name.
  def normalize(value) do
    {:ok, json_value(value)}
  catch
    {:non_portable, reason} -> {:error, reason}
  end

  defp json_value(value) when is_struct(value),
    do: throw({:non_portable, {:unsupported_json_value, value}})

  defp json_value(value) when is_map(value) do
    out = Map.new(value, fn {key, item} -> {object_key(key), json_value(item)} end)

    if map_size(out) == map_size(value) do
      out
    else
      keys =
        value
        |> Map.keys()
        |> Enum.group_by(&object_key/1)
        |> Enum.find(fn {_, ks} -> length(ks) > 1 end)

      throw({:non_portable, {:duplicate_object_key_after_stringification, keys}})
    end
  end

  defp json_value(value) when is_list(value), do: Enum.map(value, &json_value/1)
  defp json_value(value) when is_tuple(value), do: value |> Tuple.to_list() |> json_value()
  defp json_value(value) when value in [true, false, nil], do: value
  defp json_value(value) when is_atom(value), do: Atom.to_string(value)
  defp json_value(value), do: value

  defp object_key(key) when is_binary(key), do: key
  defp object_key(key) when is_atom(key), do: Atom.to_string(key)
  defp object_key(key) when is_integer(key), do: Integer.to_string(key)
  defp object_key(key), do: throw({:non_portable, {:non_string_object_key, key}})

  defp repository(value) when is_binary(value) do
    case String.split(value, "/", parts: 3) do
      [owner, name] when owner != "" and name != "" -> :ok
      _ -> {:error, {:invalid_repository, value}}
    end
  end

  defp repository(value), do: {:error, {:invalid_repository, value}}

  defp producer_sha(value) when is_binary(value) do
    if Regex.match?(@sha, value), do: :ok, else: {:error, {:invalid_producer_sha, value}}
  end

  defp producer_sha(value), do: {:error, {:invalid_producer_sha, value}}

  defp digest_value(field, value) when is_binary(value) do
    if Regex.match?(@digest, value), do: :ok, else: {:error, {:invalid_digest, field, value}}
  end

  defp digest_value(field, value), do: {:error, {:invalid_digest, field, value}}
end

defmodule Ex4pm.Gall.Corpus do
  @moduledoc "GALL-015 executable process reference corpus."

  alias Ex4pm.Gall

  @fixtures [
    %{
      id: "sequence",
      semantic: %{type: :sequence, children: ["a", "b", "c"]},
      traces: [["a", "b", "c"]],
      expected: %{relations: [{"a", "b"}, {"a", "c"}, {"b", "c"}]}
    },
    %{
      id: "parallel",
      semantic: %{type: :partial_order, children: ["a", "b"], order: []},
      traces: [["a", "b"], ["b", "a"]],
      expected: %{concurrent: [{"a", "b"}]}
    },
    %{
      id: "choice",
      semantic: %{type: :choice, children: ["a", "b"]},
      traces: [["a"], ["b"]],
      expected: %{choice: true}
    },
    %{
      id: "loop",
      semantic: %{type: :loop, body: "a", redo: "b"},
      traces: [["a"], ["a", "b", "a"]],
      expected: %{loop: true}
    },
    %{
      id: "hierarchy",
      semantic: %{
        type: :hierarchy,
        id: "parent",
        child: %{type: :sequence, children: ["a", "b"]}
      },
      traces: [["a", "b"]],
      expected: %{hierarchy: true}
    },
    %{
      id: "object-centric",
      ocel: %{
        events: [
          %{id: "e1", activity: "create", sequence: 1, objects: [{"order:1", "order", "target"}]},
          %{
            id: "e2",
            activity: "ship",
            sequence: 2,
            objects: [
              {"order:1", "order", "target"},
              {"item:1", "item", "contains"}
            ]
          }
        ]
      },
      expected: %{multi_object: true}
    },
    %{
      id: "invalid-order-cycle",
      semantic: %{
        type: :partial_order,
        children: ["a", "b"],
        order: [{"a", "b"}, {"b", "a"}]
      },
      expected_refusal: :cyclic_partial_order
    }
  ]

  def fixtures, do: @fixtures

  def fixture!(id) do
    Enum.find(@fixtures, &(&1.id == id)) ||
      raise ArgumentError, "unknown GALL process fixture #{inspect(id)}"
  end

  def manifest do
    %{
      schema: "ex4pm.gall.process-corpus/v26.9.18",
      fixture_ids: Enum.map(@fixtures, & &1.id),
      fixture_digests: Map.new(@fixtures, &{&1.id, Gall.digest(&1)})
    }
  end

  def manifest_digest, do: Gall.digest(manifest())
end

defmodule Ex4pm.Gall.Powl do
  @moduledoc "GALL-016 canonical POWL-like reference algebra with dual ingress."

  alias Ex4pm.Gall

  @types [:task, :sequence, :partial_order, :choice, :loop, :hierarchy]

  def from_semantic(spec) when is_map(spec) do
    with {:ok, normalized} <- normalize(spec),
         :ok <- validate(normalized) do
      {:ok, receipt(normalized, :semantic)}
    end
  end

  @doc """
  WF-net ingress. `flow` may connect transitions directly or through places;
  the admitted order is reachability in the whole flow graph restricted to
  transition pairs, so `a -> p1 -> b` orders `a` before `b` exactly as a
  direct `a -> b` arc does. Duplicate transitions and malformed arcs are
  refused rather than silently merged or dropped.
  """
  def from_wfnet(%{transitions: transitions, flow: flow} = net)
      when is_list(transitions) and is_list(flow) do
    transitions = Enum.map(transitions, &to_string/1)

    with :ok <- validate_wfnet(net),
         :ok <- unique_transitions(transitions),
         {:ok, arcs} <- wfnet_arcs(flow) do
      transition_set = MapSet.new(transitions)

      order =
        arcs
        |> transitive_closure()
        |> Enum.filter(fn {left, right} ->
          MapSet.member?(transition_set, left) and MapSet.member?(transition_set, right)
        end)
        |> Enum.sort()

      spec = %{type: :partial_order, children: Enum.sort(transitions), order: order}

      with {:ok, normalized} <- normalize(spec),
           :ok <- validate(normalized) do
        {:ok, receipt(normalized, :wfnet)}
      end
    end
  end

  def from_wfnet(_), do: {:error, :invalid_wfnet}

  def semantic_properties(%{model: model}), do: semantic_properties(model)

  def semantic_properties(%{type: :task, id: id}), do: %{tasks: [id], relations: [], type: :task}

  def semantic_properties(%{type: :sequence, children: children}) do
    tasks = flatten_tasks(children)

    relations =
      for {left, i} <- Enum.with_index(tasks),
          {right, j} <- Enum.with_index(tasks),
          i < j,
          do: {left, right}

    %{tasks: tasks, relations: Enum.sort(relations), type: :sequence}
  end

  def semantic_properties(%{type: :partial_order, children: children, order: order}) do
    %{tasks: flatten_tasks(children), relations: transitive_closure(order), type: :partial_order}
  end

  def semantic_properties(%{type: :choice, children: children}) do
    %{tasks: flatten_tasks(children), relations: [], type: :choice}
  end

  def semantic_properties(%{type: :loop, body: body, redo: redo}) do
    %{tasks: flatten_tasks([body, redo]), relations: [], type: :loop}
  end

  def semantic_properties(%{type: :hierarchy, id: id, child: child}) do
    child_props = semantic_properties(child)
    Map.merge(child_props, %{type: :hierarchy, hierarchy: [id]})
  end

  def equivalent?(left, right) do
    semantic_properties(left) == semantic_properties(right)
  end

  defp receipt(model, ingress) do
    %{
      schema: "ex4pm.gall.powl/v26.9.18",
      ingress: ingress,
      model: model,
      model_digest: Gall.digest(model)
    }
  end

  defp normalize(task) when is_binary(task), do: {:ok, %{type: :task, id: task}}

  defp normalize(%{type: :task, id: id}) when is_binary(id),
    do: {:ok, %{type: :task, id: id}}

  defp normalize(%{type: type, children: children}) when type in [:sequence, :choice] do
    with {:ok, normalized} <- normalize_children(children) do
      {:ok, %{type: type, children: normalized}}
    end
  end

  defp normalize(%{type: :partial_order, children: children} = spec) do
    with {:ok, normalized} <- normalize_children(children),
         {:ok, order} <- normalize_order(Map.get(spec, :order, [])) do
      {:ok, %{type: :partial_order, children: normalized, order: order}}
    end
  end

  defp normalize(%{type: :loop, body: body, redo: redo}) do
    with {:ok, body} <- normalize(body),
         {:ok, redo} <- normalize(redo) do
      {:ok, %{type: :loop, body: body, redo: redo}}
    end
  end

  defp normalize(%{type: :hierarchy, id: id, child: child}) when is_binary(id) do
    with {:ok, child} <- normalize(child) do
      {:ok, %{type: :hierarchy, id: id, child: child}}
    end
  end

  defp normalize(%{type: other}), do: {:error, {:unsupported_powl_construct, other}}
  defp normalize(_), do: {:error, :invalid_powl}

  defp normalize_children(children) when is_list(children) and children != [] do
    children
    |> Enum.reduce_while({:ok, []}, fn child, {:ok, acc} ->
      case normalize(child) do
        {:ok, value} -> {:cont, {:ok, [value | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      error -> error
    end
  end

  defp normalize_children(_), do: {:error, :empty_children}

  defp normalize_order(order) when is_list(order) do
    Enum.reduce_while(order, {:ok, []}, fn
      {a, b}, {:ok, acc} when (is_binary(a) or is_atom(a)) and (is_binary(b) or is_atom(b)) ->
        {:cont, {:ok, [{to_string(a), to_string(b)} | acc]}}

      edge, _ ->
        {:halt, {:error, {:invalid_partial_order_edge, edge}}}
    end)
    |> case do
      {:ok, edges} -> {:ok, Enum.reverse(edges)}
      error -> error
    end
  end

  defp normalize_order(order), do: {:error, {:invalid_partial_order_edge, order}}

  defp validate(%{type: type}) when type not in @types,
    do: {:error, {:unsupported_powl_construct, type}}

  defp validate(%{type: :partial_order, order: order, children: children}) do
    tasks = MapSet.new(flatten_tasks(children))

    cond do
      Enum.any?(order, fn {a, b} ->
        not MapSet.member?(tasks, a) or not MapSet.member?(tasks, b)
      end) ->
        {:error, :partial_order_unknown_task}

      cyclic?(order) ->
        {:error, :cyclic_partial_order}

      true ->
        validate_all(children)
    end
  end

  defp validate(%{type: type, children: children}) when type in [:sequence, :choice],
    do: validate_all(children)

  defp validate(%{type: :loop, body: body, redo: redo}), do: validate_all([body, redo])
  defp validate(%{type: :hierarchy, child: child}), do: validate(child)
  defp validate(%{type: :task}), do: :ok

  defp validate_all(items) do
    Enum.reduce_while(items, :ok, fn item, :ok ->
      case validate(item) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp unique_transitions(transitions) do
    case transitions -- Enum.uniq(transitions) do
      [] -> :ok
      [dup | _] -> {:error, {:duplicate_wfnet_transition, dup}}
    end
  end

  defp wfnet_arcs(flow) do
    Enum.reduce_while(flow, {:ok, []}, fn
      {left, right}, {:ok, acc}
      when (is_binary(left) or is_atom(left)) and (is_binary(right) or is_atom(right)) ->
        {:cont, {:ok, [{to_string(left), to_string(right)} | acc]}}

      arc, _ ->
        {:halt, {:error, {:invalid_wfnet_arc, arc}}}
    end)
  end

  defp validate_wfnet(%{transitions: transitions}) when transitions != [], do: :ok
  defp validate_wfnet(_), do: {:error, :invalid_wfnet}

  defp flatten_tasks(items) when is_list(items), do: Enum.flat_map(items, &flatten_tasks/1)
  defp flatten_tasks(%{type: :task, id: id}), do: [id]
  defp flatten_tasks(%{type: :hierarchy, child: child}), do: flatten_tasks(child)
  defp flatten_tasks(%{type: :loop, body: body, redo: redo}), do: flatten_tasks([body, redo])
  defp flatten_tasks(%{children: children}), do: flatten_tasks(children)
  defp flatten_tasks(item) when is_binary(item), do: [item]

  # Kahn's algorithm: O(V + E), no closure materialization.
  defp cyclic?(edges) do
    edges = Enum.uniq(edges)
    nodes = edges |> Enum.flat_map(fn {a, b} -> [a, b] end) |> Enum.uniq()

    indegree =
      Enum.reduce(edges, Map.new(nodes, &{&1, 0}), fn {_, b}, acc ->
        Map.update!(acc, b, &(&1 + 1))
      end)

    adjacency = Enum.reduce(edges, %{}, fn {a, b}, acc -> Map.update(acc, a, [b], &[b | &1]) end)
    ready = for {node, 0} <- indegree, do: node
    kahn(ready, adjacency, indegree, 0) < length(nodes)
  end

  defp kahn([], _adjacency, _indegree, removed), do: removed

  defp kahn([node | ready], adjacency, indegree, removed) do
    {ready, indegree} =
      adjacency
      |> Map.get(node, [])
      |> Enum.reduce({ready, indegree}, fn next, {ready, indegree} ->
        degree = Map.fetch!(indegree, next) - 1
        indegree = Map.put(indegree, next, degree)
        if degree == 0, do: {[next | ready], indegree}, else: {ready, indegree}
      end)

    kahn(ready, adjacency, indegree, removed + 1)
  end

  # Reachability closure by one DFS per source node: O(V * (V + E)) instead
  # of iterated pairwise joins, so WF-nets routed through places stay cheap.
  defp transitive_closure(edges) do
    adjacency =
      Enum.reduce(edges, %{}, fn {a, b}, acc -> Map.update(acc, a, [b], &[b | &1]) end)

    adjacency
    |> Map.keys()
    |> Enum.flat_map(fn source ->
      source
      |> reachable(adjacency)
      |> Enum.map(&{source, &1})
    end)
    |> Enum.sort()
  end

  defp reachable(source, adjacency) do
    do_reachable(Map.get(adjacency, source, []), adjacency, MapSet.new())
    |> MapSet.to_list()
  end

  defp do_reachable([], _adjacency, seen), do: seen

  defp do_reachable([node | rest], adjacency, seen) do
    if MapSet.member?(seen, node) do
      do_reachable(rest, adjacency, seen)
    else
      do_reachable(Map.get(adjacency, node, []) ++ rest, adjacency, MapSet.put(seen, node))
    end
  end
end

defmodule Ex4pm.Gall.Ocpq do
  @moduledoc "GALL-017 object-centric process-query reference evaluator."

  alias Ex4pm.Gall

  def evaluate(%{events: events}, query) when is_list(events) and is_map(query) do
    with :ok <- validate_events(events),
         :ok <- validate_query(query) do
      matches =
        events
        |> Enum.filter(&matches?(&1, query, events))
        |> Enum.map(&event_binding/1)
        |> Enum.sort_by(&Gall.digest/1)

      violations =
        case {Map.get(query, :require_match, true), matches} do
          {true, []} -> [%{type: :missing_required_binding, query: query}]
          _ -> []
        end

      result = %{
        bindings: matches,
        violations: violations,
        standing: if(violations == [], do: :pass, else: :violation)
      }

      {:ok, Map.put(result, :result_digest, Gall.digest(result))}
    end
  end

  def evaluate(_, _), do: {:error, :invalid_ocel}

  defp validate_events(events) do
    case Enum.find(events, &(not valid_event?(&1))) do
      nil -> :ok
      event -> {:error, {:invalid_ocel_event, event}}
    end
  end

  defp valid_event?(%{objects: objects} = event) when is_list(objects) do
    Map.has_key?(event, :id) and
      Enum.all?(objects, &match?({_id, _type, _qualifier}, &1))
  end

  defp valid_event?(%{} = event),
    do: Map.has_key?(event, :id) and not Map.has_key?(event, :objects)

  defp valid_event?(_), do: false

  defp validate_query(query) do
    supported =
      Map.keys(query) -- [:activity, :object_type, :qualifier, :after_activity, :require_match]

    if supported == [] do
      :ok
    else
      {:error, {:unsupported_ocpq_operator, hd(supported)}}
    end
  end

  defp matches?(event, query, events) do
    activity_ok = is_nil(query[:activity]) or event[:activity] == query[:activity]

    object_ok =
      is_nil(query[:object_type]) or
        Enum.any?(event[:objects] || [], fn {_id, type, _qualifier} ->
          type == query[:object_type]
        end)

    qualifier_ok =
      is_nil(query[:qualifier]) or
        Enum.any?(event[:objects] || [], fn {_id, _type, qualifier} ->
          qualifier == query[:qualifier]
        end)

    after_ok =
      is_nil(query[:after_activity]) or
        Enum.any?(events, fn prior ->
          prior[:activity] == query[:after_activity] and
            is_integer(prior[:sequence]) and
            is_integer(event[:sequence]) and
            prior[:sequence] < event[:sequence]
        end)

    activity_ok and object_ok and qualifier_ok and after_ok
  end

  defp event_binding(event) do
    %{
      event_id: event[:id],
      activity: event[:activity],
      sequence: event[:sequence],
      objects: Enum.sort(event[:objects] || [])
    }
  end
end

defmodule Ex4pm.Gall.Discovery do
  @moduledoc "GALL-018 rule-constrained deterministic discovery."

  alias Ex4pm.Gall

  def discover(traces, rules \\ [])

  def discover(traces, rules) when is_list(traces) and is_list(rules) do
    case Enum.find(traces, &(not valid_trace?(&1))) do
      nil -> do_discover(traces, rules)
      trace -> {:error, {:invalid_trace, trace}}
    end
  end

  def discover(_traces, _rules), do: {:error, :invalid_discovery_input}

  defp valid_trace?(trace) when is_list(trace), do: Enum.all?(trace, &is_binary/1)
  defp valid_trace?(_), do: false

  defp do_discover(traces, rules) do
    edges =
      traces
      |> Enum.flat_map(fn trace -> Enum.zip(trace, Enum.drop(trace, 1)) end)
      |> Enum.frequencies()
      |> Enum.sort()

    deviations = Enum.flat_map(rules, &rule_deviation(&1, edges, traces))

    candidate = %{
      type: :dfg,
      edges: edges,
      standing: :candidate,
      rule_digest: Gall.digest(rules),
      observation_digest: Gall.digest(traces)
    }

    if Enum.any?(deviations, &(&1.severity == :hard)) do
      {:ok, %{candidates: [], deviations: deviations, standing: :blocked}}
    else
      {:ok, %{candidates: [candidate], deviations: deviations, standing: :candidate}}
    end
  end

  defp rule_deviation({:forbid_edge, a, b}, edges, _traces) do
    if Enum.any?(edges, fn {{left, right}, _} -> left == a and right == b end) do
      [%{type: :forbidden_edge_observed, edge: {a, b}, severity: :hard}]
    else
      []
    end
  end

  defp rule_deviation({:require_edge, a, b}, edges, _traces) do
    if Enum.any?(edges, fn {{left, right}, _} -> left == a and right == b end) do
      []
    else
      [%{type: :required_edge_missing, edge: {a, b}, severity: :hard}]
    end
  end

  defp rule_deviation({:before, a, b}, _edges, traces) do
    violated =
      Enum.any?(traces, fn trace ->
        ia = Enum.find_index(trace, &(&1 == a))
        ib = Enum.find_index(trace, &(&1 == b))
        not is_nil(ia) and not is_nil(ib) and ia >= ib
      end)

    if violated, do: [%{type: :ordering_violation, pair: {a, b}, severity: :hard}], else: []
  end

  defp rule_deviation(rule, _edges, _traces),
    do: [%{type: :unsupported_rule, rule: rule, severity: :hard}]
end

defmodule Ex4pm.Gall.Compliance do
  @moduledoc "GALL-019 deterministic candidate-only compliance baseline."

  alias Ex4pm.Gall

  def train(rows) when is_list(rows) and rows != [] do
    labels = Enum.map(rows, &Map.fetch!(&1, :label))

    {majority, majority_count} =
      labels
      |> Enum.frequencies()
      |> Enum.min_by(fn {label, count} -> {-count, to_string(label)} end)

    model = %{
      kind: :majority_baseline,
      majority_label: majority,
      # Integer basis points: the portable envelope refuses floats, so the
      # prediction must stay inside the cross-language JCS subset.
      majority_share_bp: div(majority_count * 10_000, length(labels)),
      training_subjects: rows |> Enum.map(&Map.fetch!(&1, :subject_id)) |> Enum.sort(),
      training_digest: Gall.digest(rows)
    }

    Map.put(model, :model_digest, Gall.digest(model))
  end

  def predict(model, subject_id, features) do
    %{
      subject_id: subject_id,
      features_digest: Gall.digest(features),
      predicted_label: model.majority_label,
      score_bp: model.majority_share_bp,
      model_digest: model.model_digest,
      standing: :candidate
    }
  end

  def split_by_subject(rows) do
    grouped = rows |> Enum.group_by(&Map.fetch!(&1, :subject_id)) |> Enum.sort()

    if length(grouped) < 3 do
      {:error, :insufficient_subjects}
    else
      n = length(grouped)
      train_n = max(1, div(n * 6, 10))
      val_n = max(1, div(n * 2, 10))
      {train, rest} = Enum.split(grouped, train_n)
      {validation, test} = Enum.split(rest, val_n)

      if test == [] do
        [last | validation] = Enum.reverse(validation)
        test = [last]
        validation = Enum.reverse(validation)
        {:ok, unpack(train), unpack(validation), unpack(test)}
      else
        {:ok, unpack(train), unpack(validation), unpack(test)}
      end
    end
  end

  defp unpack(groups), do: Enum.flat_map(groups, &elem(&1, 1))
end

defmodule Ex4pm.Gall.Compute do
  @moduledoc """
  GALL-020 typed deterministic process-compute dispatcher.

  `select/2` binds a capability to an input under a selection digest and
  authority `:none`. `execute/1` recomputes that digest before running, so a
  stale, forged or re-targeted selection is refused instead of producing a
  receipt that names a subject it did not compute. Executors are named
  functions (module attributes cannot carry closures), and malformed input
  is refused with a typed error rather than crashing the dispatcher.
  """

  alias Ex4pm.Gall
  alias Ex4pm.Gall.{Compliance, Discovery, Ocpq, Powl}

  @version "v26.9.18"
  @capabilities [:powl_semantic, :powl_wfnet, :ocpq, :discover, :compliance_predict]

  def capabilities do
    Map.new(@capabilities, &{&1, %{version: @version}})
  end

  def select(capability, input) when is_atom(capability) do
    if capability in @capabilities do
      {:ok,
       %{
         capability: capability,
         input: input,
         selection_digest: selection_digest(capability, input),
         authority: :none
       }}
    else
      {:error, {:unsupported_process_capability, capability}}
    end
  end

  def select(capability, _input), do: {:error, {:unsupported_process_capability, capability}}

  def execute(%{capability: capability, input: input, selection_digest: digest} = selection) do
    cond do
      capability not in @capabilities ->
        {:error, {:unsupported_process_capability, capability}}

      Map.get(selection, :authority, :none) != :none ->
        {:error, {:authority_expanded, Map.get(selection, :authority)}}

      digest != selection_digest(capability, input) ->
        {:error, :selection_digest_mismatch}

      true ->
        case run(capability, input) do
          {:ok, result} ->
            {:ok,
             %{
               capability: capability,
               algorithm_version: @version,
               selection_digest: digest,
               result: result,
               result_digest: Gall.digest(result),
               model_required: false
             }}

          {:error, _} = error ->
            error
        end
    end
  end

  def execute(_), do: {:error, :invalid_selection}

  def execute_model_authored_result(_result),
    do: {:error, :refused_model_authored_computation_result}

  defp selection_digest(capability, input), do: Gall.digest({capability, input})

  defp run(:powl_semantic, input) when is_map(input), do: Powl.from_semantic(input)
  defp run(:powl_wfnet, input) when is_map(input), do: Powl.from_wfnet(input)

  defp run(:ocpq, %{ocel: ocel, query: query}), do: Ocpq.evaluate(ocel, query)

  defp run(:discover, %{traces: traces, rules: rules}) when is_list(traces) and is_list(rules),
    do: Discovery.discover(traces, rules)

  defp run(:compliance_predict, %{
         model: %{model_digest: _} = model,
         subject_id: subject_id,
         features: features
       }),
       do: {:ok, Compliance.predict(model, subject_id, features)}

  defp run(capability, _input), do: {:error, {:invalid_capability_input, capability}}
end
