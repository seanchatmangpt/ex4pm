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

  def from_wfnet(%{transitions: transitions, flow: flow} = net)
      when is_list(transitions) and is_list(flow) do
    transitions = Enum.map(transitions, &to_string/1) |> Enum.sort()

    order =
      flow
      |> Enum.flat_map(fn
        {left, right} when left in transitions and right in transitions -> [{left, right}]
        _ -> []
      end)
      |> transitive_closure()
      |> Enum.sort()

    spec = %{type: :partial_order, children: transitions, order: order}

    with :ok <- validate_wfnet(net),
         {:ok, normalized} <- normalize(spec),
         :ok <- validate(normalized) do
      {:ok, receipt(normalized, :wfnet)}
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
    with {:ok, normalized} <- normalize_children(children) do
      {:ok,
       %{
         type: :partial_order,
         children: normalized,
         order: Enum.map(Map.get(spec, :order, []), fn {a, b} -> {to_string(a), to_string(b)} end)
       }}
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

  defp validate(%{type: type}) when type not in @types,
    do: {:error, {:unsupported_powl_construct, type}}

  defp validate(%{type: :partial_order, order: order, children: children}) do
    tasks = MapSet.new(flatten_tasks(children))

    cond do
      Enum.any?(order, fn {a, b} -> not MapSet.member?(tasks, a) or not MapSet.member?(tasks, b) end) ->
        {:error, :partial_order_unknown_task}

      cyclic?(order) ->
        {:error, :cyclic_partial_order}

      true ->
        :ok
    end
  end

  defp validate(_), do: :ok

  defp validate_wfnet(%{transitions: transitions}) when transitions != [], do: :ok
  defp validate_wfnet(_), do: {:error, :invalid_wfnet}

  defp flatten_tasks(items) when is_list(items), do: Enum.flat_map(items, &flatten_tasks/1)
  defp flatten_tasks(%{type: :task, id: id}), do: [id]
  defp flatten_tasks(%{type: :hierarchy, child: child}), do: flatten_tasks(child)
  defp flatten_tasks(%{type: :loop, body: body, redo: redo}), do: flatten_tasks([body, redo])
  defp flatten_tasks(%{children: children}), do: flatten_tasks(children)
  defp flatten_tasks(item) when is_binary(item), do: [item]

  defp cyclic?(edges) do
    closure = transitive_closure(edges)
    Enum.any?(closure, fn {a, b} -> a == b end)
  end

  defp transitive_closure(edges) do
    edges = MapSet.new(edges)

    next =
      Enum.reduce(edges, edges, fn {a, b}, acc ->
        Enum.reduce(edges, acc, fn
          {^b, c}, inner -> MapSet.put(inner, {a, c})
          _, inner -> inner
        end)
      end)

    if MapSet.size(next) == MapSet.size(edges) do
      next |> MapSet.to_list() |> Enum.sort()
    else
      transitive_closure(MapSet.to_list(next))
    end
  end
end

defmodule Ex4pm.Gall.Ocpq do
  @moduledoc "GALL-017 object-centric process-query reference evaluator."

  alias Ex4pm.Gall

  def evaluate(%{events: events}, query) when is_list(events) and is_map(query) do
    with :ok <- validate_query(query) do
      matches =
        events
        |> Enum.filter(&matches?(&1, query))
        |> Enum.map(&binding/1)
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

  defp validate_query(query) do
    supported = Map.keys(query) -- [:activity, :object_type, :qualifier, :after_activity, :require_match]

    if supported == [] do
      :ok
    else
      {:error, {:unsupported_ocpq_operator, hd(supported)}}
    end
  end

  defp matches?(event, query) do
    activity_ok = is_nil(query[:activity]) or event[:activity] == query[:activity]

    object_ok =
      is_nil(query[:object_type]) or
        Enum.any?(event[:objects] || [], fn {_id, type, _qualifier} -> type == query[:object_type] end)

    qualifier_ok =
      is_nil(query[:qualifier]) or
        Enum.any?(event[:objects] || [], fn {_id, _type, qualifier} -> qualifier == query[:qualifier] end)

    activity_ok and object_ok and qualifier_ok
  end

  defp binding(event) do
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

  def discover(traces, rules \ []) when is_list(traces) and is_list(rules) do
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
    majority =
      labels
      |> Enum.frequencies()
      |> Enum.min_by(fn {label, count} -> {-count, to_string(label)} end)
      |> elem(0)

    model = %{
      kind: :majority_baseline,
      majority_label: majority,
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
      score: 1.0,
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
  @moduledoc "GALL-020 typed deterministic process-compute dispatcher."

  alias Ex4pm.Gall
  alias Ex4pm.Gall.{Compliance, Discovery, Ocpq, Powl}

  @capabilities %{
    powl_semantic: %{version: "v26.9.18", executor: &Powl.from_semantic/1},
    powl_wfnet: %{version: "v26.9.18", executor: &Powl.from_wfnet/1},
    ocpq: %{version: "v26.9.18", executor: fn %{ocel: ocel, query: query} -> Ocpq.evaluate(ocel, query) end},
    discover: %{version: "v26.9.18", executor: fn %{traces: traces, rules: rules} -> Discovery.discover(traces, rules) end},
    compliance_predict: %{
      version: "v26.9.18",
      executor: fn %{model: model, subject_id: subject_id, features: features} ->
        {:ok, Compliance.predict(model, subject_id, features)}
      end
    }
  }

  def capabilities do
    Map.new(@capabilities, fn {name, spec} ->
      {name, Map.drop(spec, [:executor])}
    end)
  end

  def select(capability, input) when is_atom(capability) do
    if Map.has_key?(@capabilities, capability) do
      {:ok,
       %{
         capability: capability,
         input: input,
         selection_digest: Gall.digest({capability, input}),
         authority: :none
       }}
    else
      {:error, {:unsupported_process_capability, capability}}
    end
  end

  def execute(%{capability: capability, input: input, selection_digest: selection_digest}) do
    case @capabilities[capability] do
      nil ->
        {:error, {:unsupported_process_capability, capability}}

      %{version: version, executor: executor} ->
        case executor.(input) do
          {:ok, result} ->
            receipt = %{
              capability: capability,
              algorithm_version: version,
              selection_digest: selection_digest,
              result: result,
              result_digest: Gall.digest(result),
              model_required: false
            }

            {:ok, receipt}

          error ->
            error
        end
    end
  end

  def execute_model_authored_result(_result),
    do: {:error, :refused_model_authored_computation_result}
end
