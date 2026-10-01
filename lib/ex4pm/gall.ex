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

  @doc """
  Type-faithful digest: unlike `digest/1`, atom and string keys, tuples and
  lists, and atom and string values stay distinct, so two terms that a
  capability would compute differently never share an identity. Used for
  model content addresses and compute selections.
  """
  def typed_digest(value) do
    "sha256:" <>
      (:crypto.hash(:sha256, :erlang.term_to_binary(value, [:deterministic]))
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

  @doc """
  `:ok` when `value` is inside the portable JCS subset (after the same
  normalization `build/3` applies), else the typed refusal `build/3` would
  return. Lets callers refuse non-portable input before computing.
  """
  @spec check(term()) :: :ok | {:error, term()}
  def check(value) do
    with {:ok, value} <- normalize(value), do: jcs_subset(value)
  end

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
  @moduledoc """
  GALL-015 executable process reference corpus.

  Control-flow fixtures carry both a `semantic` intent and an equivalent
  `wfnet` (places explicit, `silent` transitions for routing), so GALL-016's
  dual ingress is exercised on the same corpus, not on ad hoc inputs.
  """

  alias Ex4pm.Gall

  @fixtures [
    %{
      id: "sequence",
      semantic: %{type: :sequence, children: ["a", "b", "c"]},
      wfnet: %{
        transitions: ["a", "b", "c"],
        flow: [{"i", "a"}, {"a", "p1"}, {"p1", "b"}, {"b", "p2"}, {"p2", "c"}, {"c", "o"}]
      },
      traces: [["a", "b", "c"]],
      expected: %{relations: [{"a", "b"}, {"a", "c"}, {"b", "c"}]}
    },
    %{
      id: "parallel",
      semantic: %{type: :partial_order, children: ["a", "b"], order: []},
      wfnet: %{
        transitions: ["split", "a", "b", "join"],
        silent: ["split", "join"],
        flow: [
          {"i", "split"},
          {"split", "p1"},
          {"split", "p2"},
          {"p1", "a"},
          {"p2", "b"},
          {"a", "q1"},
          {"b", "q2"},
          {"q1", "join"},
          {"q2", "join"},
          {"join", "o"}
        ]
      },
      traces: [["a", "b"], ["b", "a"]],
      expected: %{concurrent: [{"a", "b"}]}
    },
    %{
      id: "choice",
      semantic: %{type: :choice, children: ["a", "b"]},
      wfnet: %{
        transitions: ["a", "b"],
        flow: [{"i", "a"}, {"i", "b"}, {"a", "o"}, {"b", "o"}]
      },
      traces: [["a"], ["b"]],
      expected: %{choice: true}
    },
    %{
      id: "loop",
      semantic: %{type: :loop, body: "a", redo: "b"},
      wfnet: %{
        transitions: ["enter", "a", "b", "exit"],
        silent: ["enter", "exit"],
        flow: [
          {"i", "enter"},
          {"enter", "p"},
          {"p", "a"},
          {"a", "q"},
          {"q", "b"},
          {"b", "p"},
          {"q", "exit"},
          {"exit", "o"}
        ]
      },
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
  @moduledoc """
  GALL-016 canonical POWL-like reference algebra with dual ingress.

  Semantic ingress compiles an explicit construct tree. WF-net ingress
  follows Petri-net semantics:

    * a marked graph (every place has at most one producer and one consumer)
      that is acyclic is a partial order: reachability restricted to visible
      transitions; a total order over them is emitted as a sequence;
    * any other net is reduced by block-structured rules until a single
      transition remains between one source and one sink place:
      redundant place, sequence (place with one producer and one consumer),
      XOR choice (transitions with identical pre- and post-sets),
      AND concurrency (single-transition branches between one split and one
      join) and loop (body `p -> t -> q`, redo `q -> r -> p` with an entry
      into `p` and an exit from `q`);
    * a net that does not reduce is refused with
      `{:wfnet_not_block_structured, remaining}`, never re-read as a
      partial order. A place with two consumers is a choice, not concurrency.

  Transitions listed in `silent` are tau (routing only). Silent branches of a
  choice or loop are refused as unsupported constructs.
  """

  alias Ex4pm.Gall

  @types [:task, :sequence, :partial_order, :choice, :loop, :hierarchy]

  def from_semantic(spec) when is_map(spec) do
    with {:ok, normalized} <- normalize(spec),
         :ok <- validate(normalized) do
      {:ok, receipt(normalized, :semantic)}
    end
  end

  def from_semantic(_), do: {:error, :invalid_powl}

  @doc """
  WF-net ingress. `flow` may connect transitions directly (an implicit place
  is inserted) or through places (any flow node that is not a transition).
  Duplicate transitions, non-label transitions, place-to-place arcs and
  malformed arcs are refused before any computation.
  """
  def from_wfnet(%{transitions: transitions, flow: flow} = net)
      when is_list(transitions) and is_list(flow) do
    with :ok <- validate_wfnet(net),
         {:ok, transitions} <- labels(transitions, :invalid_wfnet_transition),
         :ok <- unique_transitions(transitions),
         {:ok, silent} <- silent_transitions(Map.get(net, :silent, []), transitions),
         {:ok, arcs} <- wfnet_arcs(flow),
         {:ok, graph} <- build_net(transitions, arcs),
         {:ok, spec} <- wfnet_spec(graph, transitions, silent, arcs),
         {:ok, normalized} <- normalize(spec),
         :ok <- validate(normalized) do
      {:ok, receipt(normalized, :wfnet)}
    end
  end

  def from_wfnet(_), do: {:error, :invalid_wfnet}

  def semantic_properties(%{model: model}), do: semantic_properties(model)

  def semantic_properties(%{type: :task, id: id} = model),
    do: %{tasks: [id], relations: [], type: :task, structure: structure(model)}

  def semantic_properties(%{type: :sequence, children: children} = model) do
    %{
      tasks: flatten_tasks(children),
      relations: relations(model),
      type: :sequence,
      structure: structure(model)
    }
  end

  def semantic_properties(%{type: type} = model)
      when type in [:partial_order, :choice, :loop] do
    %{
      tasks: model |> flatten_tasks() |> Enum.sort(),
      relations: relations(model),
      type: type,
      structure: structure(model)
    }
  end

  def semantic_properties(%{type: :hierarchy, id: id, child: child} = model) do
    child
    |> semantic_properties()
    |> Map.merge(%{type: :hierarchy, hierarchy: [id], structure: structure(model)})
  end

  @doc "Equivalence of required semantic properties, independent of encoding order."
  def equivalent?(left, right) do
    semantic_properties(left) == semantic_properties(right)
  end

  # Ordering relations implied by the construct tree (transitively closed).
  defp relations(%{type: :task}), do: []

  defp relations(%{type: :sequence, children: children}) do
    inner = Enum.flat_map(children, &relations/1)

    cross =
      for {left, i} <- Enum.with_index(children),
          {right, j} <- Enum.with_index(children),
          i < j,
          a <- flatten_tasks(left),
          b <- flatten_tasks(right),
          do: {a, b}

    Enum.uniq(inner ++ cross) |> Enum.sort()
  end

  defp relations(%{type: :partial_order, children: children, order: order}) do
    (Enum.flat_map(children, &relations/1) ++ transitive_closure(order))
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp relations(%{type: :choice, children: children}),
    do: children |> Enum.flat_map(&relations/1) |> Enum.uniq() |> Enum.sort()

  defp relations(%{type: :loop, body: body, redo: redo}),
    do: (relations(body) ++ relations(redo)) |> Enum.uniq() |> Enum.sort()

  defp relations(%{type: :hierarchy, child: child}), do: relations(child)

  @doc """
  Canonical construct tree: nested sequences/choices/concurrency are
  flattened, commutative operands sorted, single-operand operators elided,
  and a partial order that totally orders task children is a sequence.
  Two encodings are equivalent exactly when their structures are equal.
  """
  def structure(%{model: model}), do: structure(model)
  def structure(%{type: :task, id: id}), do: {:task, id}

  def structure(%{type: :sequence, children: children}) do
    children
    |> Enum.map(&structure/1)
    |> Enum.flat_map(fn
      {:sequence, items} -> items
      item -> [item]
    end)
    |> single_or(:sequence)
  end

  def structure(%{type: :choice, children: children}) do
    children
    |> Enum.map(&structure/1)
    |> Enum.flat_map(fn
      {:choice, items} -> items
      item -> [item]
    end)
    |> Enum.sort()
    |> single_or(:choice)
  end

  def structure(%{type: :partial_order, children: children, order: order}) do
    items = Enum.map(children, &structure/1)
    closure = transitive_closure(order)
    n = length(items)

    cond do
      closure == [] ->
        items
        |> Enum.flat_map(fn
          {:partial_order, nested, []} -> nested
          item -> [item]
        end)
        |> Enum.sort()
        |> case do
          [one] -> one
          many -> {:partial_order, many, []}
        end

      Enum.all?(items, &match?({:task, _}, &1)) and length(closure) == div(n * (n - 1), 2) ->
        successors = Enum.frequencies_by(closure, &elem(&1, 0))

        items
        |> Enum.sort_by(fn {:task, id} -> {-Map.get(successors, id, 0), id} end)
        |> then(&{:sequence, &1})

      true ->
        {:partial_order, Enum.sort(items), closure}
    end
  end

  def structure(%{type: :loop, body: body, redo: redo}),
    do: {:loop, structure(body), structure(redo)}

  def structure(%{type: :hierarchy, id: id, child: child}),
    do: {:hierarchy, id, structure(child)}

  defp single_or([one], _type), do: one
  defp single_or(items, type), do: {type, items}

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

  # ---------------------------------------------------------------- WF-net

  defp labels(values, reason) do
    Enum.reduce_while(values, {:ok, []}, fn
      value, {:ok, acc} when is_binary(value) ->
        {:cont, {:ok, [value | acc]}}

      value, {:ok, acc} when is_atom(value) and value not in [nil, true, false] ->
        {:cont, {:ok, [Atom.to_string(value) | acc]}}

      value, _ ->
        {:halt, {:error, {reason, value}}}
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      error -> error
    end
  end

  defp silent_transitions(silent, transitions) when is_list(silent) do
    with {:ok, silent} <- labels(silent, :invalid_wfnet_silent_transition) do
      case Enum.find(silent, &(&1 not in transitions)) do
        nil -> {:ok, MapSet.new(silent)}
        unknown -> {:error, {:unknown_silent_transition, unknown}}
      end
    end
  end

  defp silent_transitions(silent, _), do: {:error, {:invalid_wfnet_silent_transition, silent}}

  defp unique_transitions(transitions) do
    case transitions -- Enum.uniq(transitions) do
      [] -> :ok
      [dup | _] -> {:error, {:duplicate_wfnet_transition, dup}}
    end
  end

  defp wfnet_arcs(flow) do
    Enum.reduce_while(flow, {:ok, []}, fn
      {left, right} = arc, {:ok, acc} ->
        case labels([left, right], :invalid_wfnet_arc) do
          {:ok, [l, r]} -> {:cont, {:ok, [{l, r} | acc]}}
          {:error, _} -> {:halt, {:error, {:invalid_wfnet_arc, arc}}}
        end

      arc, _ ->
        {:halt, {:error, {:invalid_wfnet_arc, arc}}}
    end)
    |> case do
      {:ok, arcs} -> {:ok, arcs |> Enum.reverse() |> Enum.uniq()}
      error -> error
    end
  end

  defp validate_wfnet(%{transitions: transitions}) when transitions != [], do: :ok
  defp validate_wfnet(_), do: {:error, :invalid_wfnet}

  # Bipartite net: t_pre/t_post map transitions to place sets, p_pre/p_post
  # map places to transition sets. Transition-to-transition arcs get an
  # implicit place {:implicit, t1, t2}; place-to-place arcs are refused.
  defp build_net(transitions, arcs) do
    tset = MapSet.new(transitions)
    empty = Map.new(transitions, &{&1, MapSet.new()})

    Enum.reduce_while(arcs, {:ok, %{t_pre: empty, t_post: empty, p_pre: %{}, p_post: %{}}}, fn
      {left, right}, {:ok, net} ->
        case {MapSet.member?(tset, left), MapSet.member?(tset, right)} do
          {true, true} ->
            {:cont,
             {:ok,
              net
              |> connect_tp(left, {:implicit, left, right})
              |> connect_pt({:implicit, left, right}, right)}}

          {true, false} ->
            {:cont, {:ok, connect_tp(net, left, right)}}

          {false, true} ->
            {:cont, {:ok, connect_pt(net, left, right)}}

          {false, false} ->
            {:halt, {:error, {:wfnet_place_to_place_arc, {left, right}}}}
        end
    end)
  end

  defp connect_tp(net, t, p) do
    net
    |> update_in([:t_post, t], &MapSet.put(&1, p))
    |> ensure_place(p)
    |> update_in([:p_pre, p], &MapSet.put(&1, t))
  end

  defp connect_pt(net, p, t) do
    net
    |> update_in([:t_pre, t], &MapSet.put(&1, p))
    |> ensure_place(p)
    |> update_in([:p_post, p], &MapSet.put(&1, t))
  end

  defp ensure_place(net, p) do
    %{
      net
      | p_pre: Map.put_new(net.p_pre, p, MapSet.new()),
        p_post: Map.put_new(net.p_post, p, MapSet.new())
    }
  end

  defp wfnet_spec(net, transitions, silent, arcs) do
    visible = Enum.reject(transitions, &MapSet.member?(silent, &1))

    cond do
      visible == [] -> {:error, :wfnet_no_visible_transition}
      marked_graph?(net) and not cyclic?(arcs) -> {:ok, marked_graph_spec(arcs, visible)}
      true -> reduce_wfnet(net, silent)
    end
  end

  defp marked_graph?(net) do
    Enum.all?(net.p_pre, fn {_, ts} -> MapSet.size(ts) <= 1 end) and
      Enum.all?(net.p_post, fn {_, ts} -> MapSet.size(ts) <= 1 end)
  end

  # Acyclic marked graph: reachability restricted to visible transitions.
  defp marked_graph_spec(arcs, visible) do
    vset = MapSet.new(visible)

    order =
      arcs
      |> transitive_closure()
      |> Enum.filter(fn {l, r} -> MapSet.member?(vset, l) and MapSet.member?(vset, r) end)

    n = length(visible)

    if n >= 2 and length(order) == div(n * (n - 1), 2) do
      successors = Enum.frequencies_by(order, &elem(&1, 0))
      children = Enum.sort_by(visible, &{-Map.get(successors, &1, 0), &1})
      %{type: :sequence, children: children}
    else
      %{type: :partial_order, children: Enum.sort(visible), order: order}
    end
  end

  defp reduce_wfnet(net, silent) do
    models =
      Map.new(net.t_pre, fn {t, _} ->
        {t, if(MapSet.member?(silent, t), do: nil, else: %{type: :task, id: t})}
      end)

    state =
      net
      |> Map.put(:model, models)
      |> close_boundary(:t_pre, :start)
      |> close_boundary(:t_post, :end)

    sources = for {p, ts} <- state.p_pre, MapSet.size(ts) == 0, do: p
    sinks = for {p, ts} <- state.p_post, MapSet.size(ts) == 0, do: p

    cond do
      length(sources) != 1 ->
        {:error, {:wfnet_not_workflow_net, {:source_places, length(sources)}}}

      length(sinks) != 1 ->
        {:error, {:wfnet_not_workflow_net, {:sink_places, length(sinks)}}}

      true ->
        reduce_loop(state)
    end
  end

  # Transitions with an empty preset (postset) get a private boundary place;
  # two or more are joined by a silent AND-split (AND-join), matching the
  # marked-graph reading that unconnected transitions are concurrent.
  defp close_boundary(state, t_side, tag) do
    open = for {t, ps} <- state[t_side], MapSet.size(ps) == 0, do: t

    case open do
      [] ->
        state

      [t] ->
        attach_boundary(state, t, {tag, t}, tag)

      many ->
        router = {tag, :router}
        outer = {tag, :outer}
        state = put_in(state, [:model, router], nil)

        state = %{
          state
          | t_pre: Map.put(state.t_pre, router, MapSet.new()),
            t_post: Map.put(state.t_post, router, MapSet.new())
        }

        state =
          Enum.reduce(many, state, fn t, acc ->
            p = {tag, t}

            case tag do
              :start -> acc |> connect_tp(router, p) |> connect_pt(p, t)
              :end -> acc |> connect_tp(t, p) |> connect_pt(p, router)
            end
          end)

        attach_boundary(state, router, outer, tag)
    end
  end

  defp attach_boundary(state, t, p, :start), do: connect_pt(state, p, t)
  defp attach_boundary(state, t, p, :end), do: connect_tp(state, t, p)

  defp reduce_loop(state) do
    case reduce_step(state) do
      {:ok, next} -> reduce_loop(next)
      {:error, _} = error -> error
      :irreducible -> finish(state)
    end
  end

  defp finish(state) do
    case Map.keys(state.t_pre) do
      [t] ->
        if map_size(state.p_pre) == 2 and MapSet.size(state.t_pre[t]) == 1 and
             MapSet.size(state.t_post[t]) == 1 do
          case state.model[t] do
            nil -> {:error, :wfnet_no_visible_transition}
            model -> {:ok, model}
          end
        else
          {:error, {:wfnet_not_block_structured, 1}}
        end

      many ->
        {:error, {:wfnet_not_block_structured, length(many)}}
    end
  end

  defp reduce_step(state) do
    Enum.find_value(
      [&redundant_place/1, &series/1, &xor_choice/1, &and_concurrency/1, &loop/1],
      :irreducible,
      fn rule -> rule.(state) end
    )
  end

  defp single(set) do
    case MapSet.to_list(set) do
      [one] -> one
      _ -> nil
    end
  end

  # Two places with identical producer and consumer sets carry the same token.
  defp redundant_place(state) do
    state.p_pre
    |> Enum.filter(fn {p, pre} -> MapSet.size(pre) > 0 and MapSet.size(state.p_post[p]) > 0 end)
    |> Enum.group_by(fn {p, pre} -> {pre, state.p_post[p]} end, &elem(&1, 0))
    |> Enum.find_value(fn {_, places} ->
      case Enum.sort(places) do
        [_keep, drop | _] -> {:ok, remove_place(state, drop)}
        _ -> nil
      end
    end)
  end

  defp series(state) do
    state.p_pre
    |> Enum.sort()
    |> Enum.find_value(fn {p, pre} ->
      with t1 when not is_nil(t1) <- single(pre),
           t2 when not is_nil(t2) <- single(state.p_post[p]),
           true <- t1 != t2,
           true <- state.t_post[t1] == MapSet.new([p]),
           true <- state.t_pre[t2] == MapSet.new([p]) do
        model = seq(state.model[t1], state.model[t2])

        {:ok,
         state
         |> remove_place(p)
         |> rewire_post(t2, t1)
         |> remove_transition(t2)
         |> put_in([:model, t1], model)}
      else
        _ -> nil
      end
    end)
  end

  defp xor_choice(state) do
    state.t_pre
    |> Enum.filter(fn {t, pre} -> MapSet.size(pre) > 0 and MapSet.size(state.t_post[t]) > 0 end)
    |> Enum.group_by(fn {t, pre} -> {pre, state.t_post[t]} end, &elem(&1, 0))
    |> Enum.sort()
    |> Enum.find_value(fn {_, ts} ->
      case Enum.sort(ts) do
        [t1, t2 | _] ->
          if is_nil(state.model[t1]) or is_nil(state.model[t2]) do
            {:error, {:unsupported_wfnet_construct, :silent_choice_branch}}
          else
            model = combine(:choice, state.model[t1], state.model[t2])
            {:ok, state |> remove_transition(t2) |> put_in([:model, t1], model)}
          end

        _ ->
          nil
      end
    end)
  end

  # Single-transition branches p_i -> t_i -> q_i sharing one split producer
  # and one join consumer are concurrent.
  defp and_concurrency(state) do
    state.t_pre
    |> Enum.flat_map(fn {t, pre} ->
      with p when not is_nil(p) <- single(pre),
           q when not is_nil(q) <- single(state.t_post[t]),
           true <- p != q,
           split when not is_nil(split) <- single(state.p_pre[p]),
           join when not is_nil(join) <- single(state.p_post[q]),
           true <- state.p_post[p] == MapSet.new([t]),
           true <- state.p_pre[q] == MapSet.new([t]),
           true <- split != t and join != t do
        [{{split, join}, t}]
      else
        _ -> []
      end
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.sort()
    |> Enum.find_value(fn {_, ts} ->
      case Enum.sort(ts) do
        [t1, t2 | _] ->
          p2 = single(state.t_pre[t2])
          q2 = single(state.t_post[t2])
          model = combine(:partial_order, state.model[t1], state.model[t2])

          {:ok,
           state
           |> remove_transition(t2)
           |> remove_place(p2)
           |> remove_place(q2)
           |> put_in([:model, t1], model)}

        _ ->
          nil
      end
    end)
  end

  defp loop(state) do
    state.t_pre
    |> Enum.sort()
    |> Enum.find_value(fn {tb, pre} ->
      with p when not is_nil(p) <- single(pre),
           q when not is_nil(q) <- single(state.t_post[tb]),
           true <- p != q,
           true <- state.p_post[p] == MapSet.new([tb]),
           true <- state.p_pre[q] == MapSet.new([tb]),
           tr when not is_nil(tr) <-
             Enum.find(Enum.sort(state.p_post[q]), fn tr ->
               tr != tb and state.t_pre[tr] == MapSet.new([q]) and
                 state.t_post[tr] == MapSet.new([p])
             end),
           true <- MapSet.size(MapSet.delete(state.p_pre[p], tr)) > 0,
           true <- MapSet.size(MapSet.delete(state.p_post[q], tr)) > 0 do
        if is_nil(state.model[tb]) or is_nil(state.model[tr]) do
          {:error, {:unsupported_wfnet_construct, :silent_loop_operand}}
        else
          model = %{type: :loop, body: state.model[tb], redo: state.model[tr]}
          {:ok, state |> remove_transition(tr) |> put_in([:model, tb], model)}
        end
      else
        _ -> nil
      end
    end)
  end

  defp seq(nil, right), do: right
  defp seq(left, nil), do: left

  defp seq(left, right),
    do: %{type: :sequence, children: operands(:sequence, left) ++ operands(:sequence, right)}

  defp combine(:choice, left, right),
    do: %{type: :choice, children: Enum.sort(operands(:choice, left) ++ operands(:choice, right))}

  defp combine(:partial_order, nil, right), do: right
  defp combine(:partial_order, left, nil), do: left

  defp combine(:partial_order, left, right) do
    %{
      type: :partial_order,
      children: Enum.sort(operands(:partial_order, left) ++ operands(:partial_order, right)),
      order: []
    }
  end

  defp operands(:partial_order, %{type: :partial_order, order: [], children: children}),
    do: children

  defp operands(:partial_order, model), do: [model]
  defp operands(type, %{type: type, children: children}), do: children
  defp operands(_type, model), do: [model]

  defp remove_place(state, p) do
    t_pre =
      Enum.reduce(state.p_post[p], state.t_pre, fn t, acc ->
        Map.update!(acc, t, &MapSet.delete(&1, p))
      end)

    t_post =
      Enum.reduce(state.p_pre[p], state.t_post, fn t, acc ->
        Map.update!(acc, t, &MapSet.delete(&1, p))
      end)

    %{
      state
      | t_pre: t_pre,
        t_post: t_post,
        p_pre: Map.delete(state.p_pre, p),
        p_post: Map.delete(state.p_post, p)
    }
  end

  defp remove_transition(state, t) do
    p_post =
      Enum.reduce(state.t_pre[t], state.p_post, fn p, acc ->
        Map.update!(acc, p, &MapSet.delete(&1, t))
      end)

    p_pre =
      Enum.reduce(state.t_post[t], state.p_pre, fn p, acc ->
        Map.update!(acc, p, &MapSet.delete(&1, t))
      end)

    %{
      state
      | p_pre: p_pre,
        p_post: p_post,
        t_pre: Map.delete(state.t_pre, t),
        t_post: Map.delete(state.t_post, t),
        model: Map.delete(state.model, t)
    }
  end

  # t_from's output places become t_to's output places.
  defp rewire_post(state, t_from, t_to) do
    Enum.reduce(state.t_post[t_from], state, fn p, acc -> acc |> connect_tp(t_to, p) end)
  end

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
  @moduledoc """
  GALL-017 object-centric process-query reference evaluator.

  Query AST (a map; any other key is refused as an unsupported operator):

    * `activity`       - the bound event's activity equals the value
    * `object_type`    - the bound event relates an object of this type
    * `qualifier`      - the bound event relates an object with this qualifier
    * `after_activity` - some event with this activity and a strictly
      smaller integer `sequence` relates at least one object that the bound
      event also relates (object-centric: unrelated objects never satisfy it)
    * `require_match`  - boolean, default true: an empty binding set is a
      `:missing_required_binding` violation, never a vacuous pass; any
      non-boolean value is refused

  Two different events may not share an id (identical re-delivery is kept
  and visible as duplicate bindings).

  Events need an `id`; `sequence`, when present, must be an integer; objects
  are `{object_id, object_type, qualifier}` triples. Each verdict binds the
  evaluator identity, the query digest and an event-order-invariant log
  digest into `result_digest`.
  """

  alias Ex4pm.Gall

  @evaluator "ex4pm.gall.ocpq/v26.9.18"
  @operators [:activity, :object_type, :qualifier, :after_activity, :require_match]

  def evaluator, do: @evaluator

  def evaluate(%{events: events}, query) when is_list(events) and is_map(query) do
    with :ok <- validate_events(events),
         :ok <- validate_query(query) do
      first = first_by_object(events, query[:after_activity])

      matches =
        events
        |> Enum.filter(&matches?(&1, query, first))
        |> Enum.map(&event_binding/1)
        |> Enum.sort_by(&Gall.digest/1)

      violations =
        case {Map.get(query, :require_match, true), matches} do
          {true, []} -> [%{type: :missing_required_binding, query: query}]
          _ -> []
        end

      result = %{
        evaluator: @evaluator,
        query_digest: Gall.digest(query),
        log_digest: events |> Enum.map(&Gall.digest/1) |> Enum.sort() |> Gall.digest(),
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
      nil -> unique_event_ids(events)
      event -> {:error, {:invalid_ocel_event, event}}
    end
  end

  # Event identity is the binding key. Re-delivery of the identical event is
  # kept visible (duplicate bindings); two *different* events under one id
  # make a binding ambiguous, so that log is refused rather than read.
  defp unique_event_ids(events) do
    events
    |> Enum.group_by(& &1.id)
    |> Enum.find(fn {_id, group} -> group |> Enum.uniq() |> length() > 1 end)
    |> case do
      nil -> :ok
      {id, _} -> {:error, {:conflicting_ocel_event_id, id}}
    end
  end

  defp valid_event?(%{} = event) do
    Map.has_key?(event, :id) and valid_sequence?(Map.get(event, :sequence)) and
      valid_objects?(Map.get(event, :objects, []))
  end

  defp valid_event?(_), do: false

  defp valid_sequence?(nil), do: true
  defp valid_sequence?(sequence), do: is_integer(sequence)

  defp valid_objects?(objects) when is_list(objects),
    do: Enum.all?(objects, &match?({_id, _type, _qualifier}, &1))

  defp valid_objects?(_), do: false

  defp validate_query(query) do
    case Map.keys(query) -- @operators do
      [] ->
        if Map.get(query, :require_match, true) in [true, false],
          do: :ok,
          else: {:error, {:invalid_ocpq_require_match, Map.get(query, :require_match)}}

      [unsupported | _] ->
        {:error, {:unsupported_ocpq_operator, unsupported}}
    end
  end

  # object_id => smallest integer sequence of an `activity` event relating
  # it: one O(events) pass instead of a scan per candidate event.
  defp first_by_object(_events, nil), do: %{}

  defp first_by_object(events, activity) do
    for %{activity: ^activity, sequence: sequence} = event when is_integer(sequence) <- events,
        {object_id, _type, _qualifier} <- Map.get(event, :objects, []),
        reduce: %{} do
      acc -> Map.update(acc, object_id, sequence, &min(&1, sequence))
    end
  end

  defp matches?(event, query, first_by_object) do
    objects = event[:objects] || []

    activity_ok = is_nil(query[:activity]) or event[:activity] == query[:activity]

    object_ok =
      is_nil(query[:object_type]) or
        Enum.any?(objects, fn {_id, type, _qualifier} -> type == query[:object_type] end)

    qualifier_ok =
      is_nil(query[:qualifier]) or
        Enum.any?(objects, fn {_id, _type, qualifier} -> qualifier == query[:qualifier] end)

    after_ok =
      is_nil(query[:after_activity]) or
        after_related?(event, objects, first_by_object)

    activity_ok and object_ok and qualifier_ok and after_ok
  end

  # A prior event (strictly smaller integer sequence) with the activity that
  # relates at least one object the bound event also relates.
  defp after_related?(%{sequence: sequence}, objects, first_by_object)
       when is_integer(sequence) do
    Enum.any?(objects, fn {object_id, _type, _qualifier} ->
      case Map.fetch(first_by_object, object_id) do
        {:ok, first} -> first < sequence
        :error -> false
      end
    end)
  end

  defp after_related?(_event, _objects, _first_by_object), do: false

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
  @moduledoc """
  GALL-018 rule-constrained deterministic discovery.

  Observations yield a candidate set, never a single forced model:

    * `:dfg`         - every observed directly-follows edge;
    * `:concurrency` - when both `a -> b` and `b -> a` are observed the log
      underdetermines cycle vs. concurrency; this candidate drops those edge
      pairs and records them as concurrent, and the ambiguity is reported;
    * `:rule_constrained` - the observed edges minus forbidden edges.

  Rules are immutable inputs. Each candidate is checked structurally against
  them; unlawful candidates are moved to `eliminated` with their violations.
  Observed rule violations are reported separately as `deviations` and never
  rewrite a rule. Lawful candidates with non-zero fitness are ranked by
  `{-fitness_bp, kind}`; with none left the result is `:blocked`.

  Rules:

    * `{:forbid_edge, a, b}` - the candidate has no `a -> b` edge;
    * `{:require_edge, a, b}` - the candidate has an `a -> b` edge;
    * `{:before, a, b}` - Declare precedence: every occurrence of `b` has an
      earlier `a` in the same trace (on a candidate: `b` is unreachable from
      the start activities without passing through `a`).

  An unsupported rule blocks the run (the envelope cannot be evaluated).
  """

  alias Ex4pm.Gall

  @algorithm "ex4pm.gall.discovery/v26.9.18"

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
    subject = %{
      algorithm: @algorithm,
      rule_digest: Gall.digest(rules),
      observation_digest: Gall.digest(traces)
    }

    base = Map.put(subject, :discovery_digest, Gall.digest(subject))

    case Enum.filter(rules, &(not supported_rule?(&1))) do
      [] ->
        rank(traces, rules, base)

      unsupported ->
        deviations = Enum.map(unsupported, &%{type: :unsupported_rule, rule: &1, severity: :hard})

        {:ok,
         Map.merge(base, %{
           candidates: [],
           eliminated: [],
           ambiguity: [],
           deviations: deviations,
           standing: :blocked
         })}
    end
  end

  defp supported_rule?({kind, a, b})
       when kind in [:forbid_edge, :require_edge, :before] and is_binary(a) and is_binary(b),
       do: true

  defp supported_rule?(_), do: false

  defp rank(traces, rules, base) do
    frequencies =
      traces
      |> Enum.flat_map(fn trace -> Enum.zip(trace, Enum.drop(trace, 1)) end)
      |> Enum.frequencies()

    observed = frequencies |> Map.keys() |> Enum.sort()
    starts = traces |> Enum.flat_map(&Enum.take(&1, 1)) |> Enum.uniq() |> Enum.sort()

    bidirectional =
      for {a, b} <- observed, a < b, Map.has_key?(frequencies, {b, a}), do: {a, b}

    forbidden = for {:forbid_edge, a, b} <- rules, do: {a, b}

    raw = [
      {:dfg, observed, []},
      {:concurrency,
       Enum.reject(observed, fn {a, b} -> {a, b} in bidirectional or {b, a} in bidirectional end),
       bidirectional},
      {:rule_constrained, observed -- forbidden, []}
    ]

    candidates =
      raw
      |> Enum.uniq_by(fn {_kind, edges, concurrent} -> {edges, concurrent} end)
      |> Enum.map(fn {kind, edges, concurrent} ->
        candidate(kind, edges, concurrent, starts, frequencies, traces, base)
      end)

    {lawful, eliminated} =
      Enum.reduce(candidates, {[], []}, fn candidate, {ok, out} ->
        case Enum.flat_map(rules, &structural_violation(&1, candidate, starts)) do
          [] ->
            {[candidate | ok], out}

          violations ->
            {ok,
             [
               %{
                 kind: candidate.kind,
                 candidate_digest: candidate.candidate_digest,
                 violations: violations
               }
               | out
             ]}
        end
      end)

    {supported, unsupported} = Enum.split_with(lawful, &(&1.fitness_bp > 0))

    eliminated =
      Enum.reverse(eliminated) ++
        Enum.map(unsupported, fn c ->
          %{
            kind: c.kind,
            candidate_digest: c.candidate_digest,
            violations: [%{type: :no_fitting_trace}]
          }
        end)

    ranked = Enum.sort_by(supported, &{-&1.fitness_bp, Atom.to_string(&1.kind)})

    ambiguity =
      case bidirectional do
        [] ->
          []

        pairs ->
          [%{type: :underdetermined, pairs: pairs, interpretations: [:cycle, :concurrency]}]
      end

    {:ok,
     Map.merge(base, %{
       candidates: ranked,
       eliminated: eliminated,
       ambiguity: ambiguity,
       deviations: Enum.flat_map(rules, &observed_deviation(&1, observed, traces)),
       standing: if(ranked == [], do: :blocked, else: :candidate)
     })}
  end

  defp candidate(kind, edges, concurrent, starts, frequencies, traces, base) do
    allowed = MapSet.new(edges ++ concurrent ++ Enum.map(concurrent, fn {a, b} -> {b, a} end))

    fitting =
      Enum.count(traces, fn trace ->
        trace |> Enum.zip(Enum.drop(trace, 1)) |> Enum.all?(&MapSet.member?(allowed, &1))
      end)

    body = %{
      type: :dfg,
      kind: kind,
      edges: Enum.map(edges, &{&1, Map.get(frequencies, &1, 0)}),
      concurrent: concurrent,
      start_activities: starts,
      fitness_bp: if(traces == [], do: 0, else: div(fitting * 10_000, length(traces))),
      standing: :candidate,
      rule_digest: base.rule_digest,
      observation_digest: base.observation_digest
    }

    Map.put(body, :candidate_digest, Gall.digest(body))
  end

  defp edge_set(candidate), do: MapSet.new(candidate.edges, &elem(&1, 0))

  defp structural_violation({:forbid_edge, a, b}, candidate, _starts) do
    if MapSet.member?(edge_set(candidate), {a, b}),
      do: [%{type: :forbidden_edge_in_candidate, edge: {a, b}}],
      else: []
  end

  defp structural_violation({:require_edge, a, b}, candidate, _starts) do
    if MapSet.member?(edge_set(candidate), {a, b}),
      do: [],
      else: [%{type: :required_edge_absent_in_candidate, edge: {a, b}}]
  end

  defp structural_violation({:before, a, b}, candidate, starts) do
    adjacency =
      candidate
      |> edge_set()
      |> MapSet.to_list()
      |> Kernel.++(Enum.flat_map(candidate.concurrent, fn {x, y} -> [{x, y}, {y, x}] end))
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

    if b in reachable_avoiding(Enum.reject(starts, &(&1 == a)), adjacency, a),
      do: [%{type: :precedence_bypass_in_candidate, pair: {a, b}}],
      else: []
  end

  defp reachable_avoiding(frontier, adjacency, avoid) do
    do_reach(frontier, adjacency, avoid, MapSet.new())
  end

  defp do_reach([], _adjacency, _avoid, seen), do: seen

  defp do_reach([node | rest], adjacency, avoid, seen) do
    if node == avoid or MapSet.member?(seen, node) do
      do_reach(rest, adjacency, avoid, seen)
    else
      do_reach(Map.get(adjacency, node, []) ++ rest, adjacency, avoid, MapSet.put(seen, node))
    end
  end

  defp observed_deviation({:forbid_edge, a, b}, observed, _traces) do
    if {a, b} in observed,
      do: [%{type: :forbidden_edge_observed, edge: {a, b}, severity: :hard}],
      else: []
  end

  defp observed_deviation({:require_edge, a, b}, observed, _traces) do
    if {a, b} in observed,
      do: [],
      else: [%{type: :required_edge_missing, edge: {a, b}, severity: :hard}]
  end

  defp observed_deviation({:before, a, b}, _observed, traces) do
    if Enum.any?(traces, &precedence_violated?(&1, a, b)),
      do: [%{type: :ordering_violation, pair: {a, b}, severity: :hard}],
      else: []
  end

  # Declare precedence(a, b): every b is preceded by some earlier a.
  defp precedence_violated?(trace, a, b) do
    Enum.reduce_while(trace, false, fn
      ^a, _seen_a -> {:halt, false}
      ^b, _ -> {:halt, true}
      _, acc -> {:cont, acc}
    end)
  end
end

defmodule Ex4pm.Gall.Compliance do
  @moduledoc """
  GALL-019 deterministic candidate-only compliance reference predictor.

  Rows are `%{subject_id: binary, label: scalar, features: %{key => scalar}}`
  with optional integer `features_at` / `label_at`. Two model kinds:

    * `:majority_baseline` - predicts the training majority label;
    * `:one_rule` - Holte's 1R: the single feature whose value table has the
      best training accuracy (ties by feature name), falling back to the
      majority for unseen values.

  `evaluate/1` splits by subject, trains both, selects on validation
  accuracy (ties keep the simpler baseline), and reports held-out test
  metrics for both: accuracy, class distribution, confusion, per-label
  precision/recall/FP/FN and score-bin calibration, all integer basis points.

  Leakage falsifiers refuse before training: a feature named like the label,
  a feature equal to the label on every row, `features_at >= label_at`, and a
  subject present in more than one split. Models are content-addressed and
  `predict/4` recomputes the model digest, so a model edited under its
  original digest is refused. Predictions are candidates with authority
  `:none`; a score below `threshold_bp` abstains.
  """

  alias Ex4pm.Gall

  @label_keys [:label, "label"]

  def train(rows, opts \\ [])

  def train(rows, opts) when is_list(rows) and rows != [] do
    with :ok <- validate_rows(rows),
         :ok <- leakage(rows) do
      build(rows, Keyword.get(opts, :kind, :majority_baseline))
    end
  end

  def train(_rows, _opts), do: {:error, :empty_training_set}

  def predict(model, subject_id, features, opts \\ [])

  def predict(model, subject_id, features, opts)
      when is_binary(subject_id) and is_map(features) do
    threshold = Keyword.get(opts, :threshold_bp, 0)

    with :ok <- verify_model(model),
         :ok <- valid_threshold(threshold) do
      {label, score} = score(model, features)

      body = %{
        subject_id: subject_id,
        features_digest: Gall.digest(features),
        predicted_label: if(score >= threshold, do: label, else: :abstain),
        score_bp: score,
        threshold_bp: threshold,
        model_kind: model.kind,
        model_digest: model.model_digest,
        standing: :candidate,
        authority: :none
      }

      {:ok, Map.put(body, :prediction_digest, Gall.digest(body))}
    end
  end

  def predict(_model, _subject_id, _features, _opts), do: {:error, :invalid_prediction_input}

  @doc "Recomputes the content address; `:ok` only for an untampered model."
  def verify_model(%{kind: kind, model_digest: digest} = model)
      when kind in [:majority_baseline, :one_rule] do
    required =
      [:majority_label, :majority_share_bp, :training_digest, :training_subjects] ++
        if kind == :one_rule, do: [:feature, :table], else: []

    cond do
      not Enum.all?(required, &Map.has_key?(model, &1)) ->
        {:error, :invalid_model}

      Gall.typed_digest(Map.delete(model, :model_digest)) != digest ->
        {:error, :model_digest_mismatch}

      true ->
        :ok
    end
  end

  def verify_model(_), do: {:error, :invalid_model}

  def split_by_subject(rows) when is_list(rows) do
    if Enum.all?(rows, &(is_map(&1) and Map.has_key?(&1, :subject_id))) do
      grouped = rows |> Enum.group_by(& &1.subject_id) |> Enum.sort()

      if length(grouped) < 3 do
        {:error, :insufficient_subjects}
      else
        n = length(grouped)
        train_n = max(1, div(n * 6, 10))
        val_n = max(1, div(n * 2, 10))
        {train, rest} = Enum.split(grouped, train_n)
        {validation, test} = Enum.split(rest, val_n)

        {validation, test} =
          if test == [] do
            [last | validation] = Enum.reverse(validation)
            {Enum.reverse(validation), [last]}
          else
            {validation, test}
          end

        {:ok, unpack(train), unpack(validation), unpack(test)}
      end
    else
      {:error, :invalid_training_row}
    end
  end

  def split_by_subject(_), do: {:error, :invalid_training_row}

  def evaluate(rows) when is_list(rows) do
    with :ok <- validate_rows(rows),
         {:ok, train, validation, test} <- split_by_subject(rows) do
      evaluate(train, validation, test)
    end
  end

  def evaluate(_), do: {:error, :invalid_training_row}

  def evaluate(train, validation, test) do
    with :ok <- disjoint_subjects(train, validation, test),
         {:ok, baseline} <- train(train, kind: :majority_baseline),
         {:ok, one_rule} <- train(train, kind: :one_rule),
         :ok <- validate_rows(validation),
         :ok <- validate_rows(test) do
      baseline_val = metrics(baseline, validation)
      one_rule_val = metrics(one_rule, validation)

      selected =
        if one_rule_val.accuracy_bp > baseline_val.accuracy_bp, do: one_rule, else: baseline

      body = %{
        split: %{
          train_subjects: subjects(train),
          validation_subjects: subjects(validation),
          test_subjects: subjects(test)
        },
        baseline: %{model: baseline, validation: baseline_val, test: metrics(baseline, test)},
        one_rule: %{model: one_rule, validation: one_rule_val, test: metrics(one_rule, test)},
        selected_kind: selected.kind,
        selected_model_digest: selected.model_digest,
        standing: :candidate,
        authority: :none
      }

      {:ok, Map.put(body, :evaluation_digest, Gall.digest(body))}
    end
  end

  # ------------------------------------------------------------ internals

  defp unpack(groups), do: Enum.flat_map(groups, &elem(&1, 1))

  defp subjects(rows), do: rows |> Enum.map(& &1.subject_id) |> Enum.uniq() |> Enum.sort()

  defp validate_rows(rows) when is_list(rows) do
    case Enum.find(rows, &(not valid_row?(&1))) do
      nil -> :ok
      row -> {:error, {:invalid_training_row, row}}
    end
  end

  defp validate_rows(rows), do: {:error, {:invalid_training_row, rows}}

  defp valid_row?(%{subject_id: subject, label: label} = row) when is_binary(subject) do
    scalar?(label) and not is_nil(label) and
      case Map.get(row, :features, %{}) do
        features when is_map(features) -> Enum.all?(features, fn {_, v} -> scalar?(v) end)
        _ -> false
      end
  end

  defp valid_row?(_), do: false

  defp scalar?(v), do: is_binary(v) or is_atom(v) or is_integer(v)

  defp features(row), do: Map.get(row, :features, %{})

  defp leakage(rows) do
    keys =
      rows |> Enum.flat_map(&Map.keys(features(&1))) |> Enum.uniq() |> Enum.sort_by(&to_string/1)

    cond do
      key = Enum.find(keys, &(&1 in @label_keys)) ->
        {:error, {:label_leakage, key}}

      key =
          Enum.find(keys, fn key ->
            Enum.all?(rows, fn row -> Map.fetch(features(row), key) == {:ok, row.label} end)
          end) ->
        {:error, {:label_leakage, key}}

      row =
          Enum.find(rows, fn row ->
            is_integer(row[:features_at]) and is_integer(row[:label_at]) and
                row.features_at >= row.label_at
          end) ->
        {:error, {:temporal_leakage, row.subject_id}}

      true ->
        :ok
    end
  end

  defp disjoint_subjects(train, validation, test) do
    [a, b, c] =
      Enum.map([train, validation, test], &MapSet.new(&1, fn row -> row[:subject_id] end))

    shared =
      MapSet.intersection(a, b)
      |> MapSet.union(MapSet.intersection(a, c))
      |> MapSet.union(MapSet.intersection(b, c))

    if MapSet.size(shared) == 0,
      do: :ok,
      else: {:error, {:subject_leakage, shared |> MapSet.to_list() |> Enum.sort()}}
  end

  defp majority(labels) do
    {label, count} =
      labels
      |> Enum.frequencies()
      |> Enum.min_by(fn {label, count} -> {-count, to_string(label)} end)

    {label, div(count * 10_000, length(labels))}
  end

  defp base_model(rows, kind) do
    {label, share} = majority(Enum.map(rows, & &1.label))

    %{
      kind: kind,
      majority_label: label,
      # Integer basis points: the portable envelope refuses floats.
      majority_share_bp: share,
      training_subjects: subjects(rows),
      training_digest: Gall.digest(rows)
    }
  end

  defp build(rows, :majority_baseline), do: {:ok, seal(base_model(rows, :majority_baseline))}

  defp build(rows, :one_rule) do
    model = base_model(rows, :one_rule)

    keys =
      rows |> Enum.flat_map(&Map.keys(features(&1))) |> Enum.uniq() |> Enum.sort_by(&to_string/1)

    best =
      keys
      |> Enum.map(fn key ->
        table =
          rows
          |> Enum.group_by(&Map.get(features(&1), key))
          |> Enum.reject(fn {value, _} -> is_nil(value) end)
          |> Enum.map(fn {value, group} ->
            {label, share} = majority(Enum.map(group, & &1.label))
            %{value: value, label: label, share_bp: share}
          end)
          |> Enum.sort_by(&Gall.digest(&1.value))

        candidate = Map.merge(model, %{feature: key, table: table})

        correct =
          Enum.count(rows, fn row -> elem(score(candidate, features(row)), 0) == row.label end)

        {correct, key, table}
      end)
      |> Enum.sort_by(fn {correct, key, _} -> {-correct, to_string(key)} end)
      |> List.first()

    case best do
      nil -> {:ok, seal(Map.merge(model, %{feature: nil, table: []}))}
      {_, key, table} -> {:ok, seal(Map.merge(model, %{feature: key, table: table}))}
    end
  end

  defp build(_rows, kind), do: {:error, {:unsupported_model_kind, kind}}

  defp seal(model), do: Map.put(model, :model_digest, Gall.typed_digest(model))

  defp score(%{kind: :one_rule, feature: key, table: table} = model, features)
       when not is_nil(key) do
    value = Map.get(features, key)

    case Enum.find(table, &(&1.value == value)) do
      %{label: label, share_bp: share} -> {label, share}
      nil -> {model.majority_label, model.majority_share_bp}
    end
  end

  defp score(model, _features), do: {model.majority_label, model.majority_share_bp}

  defp valid_threshold(t) when is_integer(t) and t >= 0 and t <= 10_000, do: :ok
  defp valid_threshold(t), do: {:error, {:invalid_threshold_bp, t}}

  @bins [{0, 2499}, {2500, 4999}, {5000, 7499}, {7500, 10_000}]

  defp metrics(model, rows) do
    pairs = Enum.map(rows, fn row -> {row.label, score(model, features(row))} end)

    labels =
      pairs
      |> Enum.flat_map(fn {actual, {pred, _}} -> [actual, pred] end)
      |> Enum.uniq()
      |> Enum.sort_by(&to_string/1)

    n = length(pairs)
    bp = fn num, den -> if den == 0, do: 0, else: div(num * 10_000, den) end
    correct = Enum.count(pairs, fn {actual, {pred, _}} -> actual == pred end)

    confusion =
      pairs
      |> Enum.frequencies_by(fn {actual, {pred, _}} -> {actual, pred} end)
      |> Enum.map(fn {{actual, pred}, count} ->
        %{actual: actual, predicted: pred, count: count}
      end)
      |> Enum.sort_by(&{to_string(&1.actual), to_string(&1.predicted)})

    per_label =
      Enum.map(labels, fn label ->
        tp = Enum.count(pairs, fn {a, {p, _}} -> a == label and p == label end)
        fp = Enum.count(pairs, fn {a, {p, _}} -> a != label and p == label end)
        fnn = Enum.count(pairs, fn {a, {p, _}} -> a == label and p != label end)

        %{
          label: label,
          support: tp + fnn,
          true_positive: tp,
          false_positive: fp,
          false_negative: fnn,
          precision_bp: bp.(tp, tp + fp),
          recall_bp: bp.(tp, tp + fnn)
        }
      end)

    calibration =
      Enum.map(@bins, fn {lo, hi} ->
        bin = Enum.filter(pairs, fn {_, {_, s}} -> s >= lo and s <= hi end)
        hits = Enum.count(bin, fn {a, {p, _}} -> a == p end)
        total = Enum.reduce(bin, 0, fn {_, {_, s}}, acc -> acc + s end)

        %{
          low_bp: lo,
          high_bp: hi,
          count: length(bin),
          mean_score_bp: if(bin == [], do: 0, else: div(total, length(bin))),
          observed_accuracy_bp: bp.(hits, length(bin))
        }
      end)

    %{
      n: n,
      accuracy_bp: bp.(correct, n),
      class_distribution:
        rows
        |> Enum.frequencies_by(& &1.label)
        |> Enum.map(fn {label, count} -> %{label: label, count: count} end)
        |> Enum.sort_by(&to_string(&1.label)),
      confusion: confusion,
      per_label: per_label,
      calibration: calibration
    }
  end
end

defmodule Ex4pm.Gall.Compute do
  @moduledoc """
  GALL-020 typed deterministic process-compute dispatcher.

  `select/2` binds a capability and the algorithm version to an input under
  a selection digest and authority `:none`. `execute/1` recomputes that
  digest before running, so a stale, forged, re-targeted or version-shifted
  selection is refused instead of producing a receipt that names a subject
  it did not compute. Each capability validates its input shape before
  dispatch; malformed input is a typed refusal, never a crash. The receipt's
  `receipt_digest` covers capability, algorithm version, selection and
  result, so replacing the algorithm version changes receipt identity.

  Input and result must lie in the Portable JCS subset (no floats, ASCII
  strings, collision-free keys), so every receipt can cross
  `Ex4pm.Gall.Portable`; anything else is refused as
  `{:non_portable_compute, :input | :result, reason}` before or after
  compute. Receipts carry deterministic, digest-bound `cost` (canonical
  input/result bytes), so replay is byte-identical; wall-clock latency is
  measured by the GALL benchmark receipt, not stored in compute receipts.
  The selection digest is type-faithful (`Ex4pm.Gall.typed_digest/1`), so an
  input re-keyed from atoms to strings is a different selection.
  """

  alias Ex4pm.Gall
  alias Ex4pm.Gall.{Compliance, Discovery, Ocpq, Portable, Powl}

  @version "v26.9.18"
  @capabilities [:powl_semantic, :powl_wfnet, :ocpq, :discover, :compliance_predict]

  def version, do: @version

  def capabilities do
    Map.new(@capabilities, &{&1, %{version: @version}})
  end

  def select(capability, input) when is_atom(capability) do
    if capability in @capabilities do
      {:ok,
       %{
         capability: capability,
         algorithm_version: @version,
         input: input,
         selection_digest: selection_digest(capability, @version, input),
         authority: :none
       }}
    else
      {:error, {:unsupported_process_capability, capability}}
    end
  end

  def select(capability, _input), do: {:error, {:unsupported_process_capability, capability}}

  def execute(%{capability: capability, input: input, selection_digest: digest} = selection) do
    version = Map.get(selection, :algorithm_version, @version)

    cond do
      capability not in @capabilities ->
        {:error, {:unsupported_process_capability, capability}}

      Map.get(selection, :authority, :none) != :none ->
        {:error, {:authority_expanded, Map.get(selection, :authority)}}

      digest != selection_digest(capability, version, input) ->
        {:error, :selection_digest_mismatch}

      version != @version ->
        {:error, {:algorithm_version_unavailable, version}}

      not valid_input?(capability, input) ->
        {:error, {:invalid_capability_input, capability}}

      true ->
        with :ok <- portable(:input, input),
             {:ok, result} <- run(capability, input),
             :ok <- portable(:result, result) do
          {:ok, receipt(capability, digest, input, result)}
        end
    end
  end

  def execute(_), do: {:error, :invalid_selection}

  # The receipt must cross the Portable envelope in every runtime, so input
  # and result are held to the portable JCS subset before and after compute.
  defp portable(side, value) do
    case Portable.check(value) do
      :ok -> :ok
      {:error, reason} -> {:error, {:non_portable_compute, side, reason}}
    end
  end

  # `receipt_digest` binds capability, algorithm version, selection, result
  # and `cost`. Cost is deterministic (canonical input/result byte sizes), so
  # replaying a selection yields a byte-identical receipt; wall-clock latency
  # is not receipt content (see Ex4pm.GallBench for measured latency).
  defp receipt(capability, digest, input, result) do
    body = %{
      capability: capability,
      algorithm_version: @version,
      selection_digest: digest,
      result: result,
      result_digest: Gall.digest(result),
      cost: %{
        input_bytes: byte_size(Portable.canonical_json(input)),
        result_bytes: byte_size(Portable.canonical_json(result))
      },
      model_required: false
    }

    Map.put(
      body,
      :receipt_digest,
      Gall.digest(
        Map.take(body, [:capability, :algorithm_version, :selection_digest, :result_digest, :cost])
      )
    )
  end

  def execute_model_authored_result(_result),
    do: {:error, :refused_model_authored_computation_result}

  @doc false
  def selection_digest(capability, version, input),
    do: Gall.typed_digest({capability, version, input})

  defp valid_input?(:powl_semantic, input), do: is_map(input)
  defp valid_input?(:powl_wfnet, %{transitions: t, flow: f}), do: is_list(t) and is_list(f)
  defp valid_input?(:ocpq, %{ocel: %{events: e}, query: q}), do: is_list(e) and is_map(q)
  defp valid_input?(:discover, %{traces: t, rules: r}), do: is_list(t) and is_list(r)

  defp valid_input?(:compliance_predict, %{model: m, subject_id: s, features: f}),
    do: is_map(m) and is_binary(s) and is_map(f)

  defp valid_input?(_, _), do: false

  defp run(:powl_semantic, input), do: Powl.from_semantic(input)
  defp run(:powl_wfnet, input), do: Powl.from_wfnet(input)
  defp run(:ocpq, %{ocel: ocel, query: query}), do: Ocpq.evaluate(ocel, query)
  defp run(:discover, %{traces: traces, rules: rules}), do: Discovery.discover(traces, rules)

  defp run(
         :compliance_predict,
         %{model: model, subject_id: subject_id, features: features} = input
       ),
       do:
         Compliance.predict(model, subject_id, features,
           threshold_bp: Map.get(input, :threshold_bp, 0)
         )
end
