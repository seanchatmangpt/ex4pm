defmodule Ex4pm.Information.Registry do
  @moduledoc """
  Closed capability registry and admission boundary.

  External protocol strings are matched against this static graph. They are
  never converted into modules, atoms, functions, or execution callbacks.
  """

  alias Ex4pm.Information.AshCatalog
  alias Ex4pm.Refusal

  defmodule Admitted do
    @moduledoc false
    @enforce_keys [
      :protocol,
      :version,
      :request_id,
      :request_hash,
      :capability,
      :handler,
      :input,
      :context,
      :options,
      :limits
    ]
    defstruct [
      :protocol,
      :version,
      :request_id,
      :request_hash,
      :capability,
      :handler,
      :input,
      :context,
      :options,
      :limits,
      resolved: %{}
    ]
  end

  @context_schema %{
    "trace_id" => %{type: :string, required?: false},
    "tenant" => %{type: :string, required?: false},
    "requester" => %{type: :string, required?: false},
    "metadata" => %{type: :map, required?: false, default: %{}}
  }

  @engine_options %{
    "engine" => %{type: :string, required?: false, default: "auto"},
    "project" => %{type: :boolean, required?: false, default: false}
  }

  @discover_options Map.merge(@engine_options, %{
                      "algorithm" => %{type: :string, required?: false, default: "dfg"}
                    })

  @capabilities %{
    "system.doctor" => %{
      handler: :system_doctor,
      description: "Inspect the complete engine candidate graph and verified contract state.",
      inputs: %{},
      options: %{}
    },
    "system.contracts" => %{
      handler: :system_contracts,
      description: "Verify and return the canonical ex4pm contract artifact graph.",
      inputs: %{},
      options: %{}
    },
    "engine.candidates" => %{
      handler: :engine_candidates,
      description: "Preserve every lawful engine candidate for an operation before selection.",
      inputs: %{
        "operation" => %{type: :string, required?: false, default: "discover"}
      },
      options: %{}
    },
    "ash.catalog" => %{
      handler: :ash_catalog,
      description: "Describe Ash resources and public actions without executing an action.",
      inputs: %{},
      options: %{}
    },
    "ash.read" => %{
      handler: :ash_read,
      description: "Execute one explicitly resolved public Ash read action.",
      inputs: %{
        "resource" => %{type: :string, required?: true},
        "action" => %{type: :string, required?: false, default: "read"},
        "params" => %{type: :map, required?: false, default: %{}}
      },
      options: %{}
    },
    "process.ingest" => %{
      handler: :process_ingest,
      description: "Normalize an OCEL 2 JSON object into the canonical ex4pm event log.",
      inputs: %{"subject" => %{type: :map, required?: true}},
      options: %{"project" => %{type: :boolean, required?: false, default: false}}
    },
    "process.ingest_xes" => %{
      handler: :process_ingest_xes,
      description: "Parse XES bytes into the canonical ex4pm event log.",
      inputs: %{"xml" => %{type: :string, required?: true}},
      options: %{"project" => %{type: :boolean, required?: false, default: false}}
    },
    "process.discover" => %{
      handler: :process_discover,
      description: "Discover a process model from OCEL 2 JSON through the DfCM engine graph.",
      inputs: %{
        "subject" => %{type: :map, required?: true},
        "object_type" => %{type: :string, required?: false}
      },
      options: @discover_options
    },
    "process.discover_file" => %{
      handler: :process_discover_file,
      description: "Read an OCEL 2 JSON file inside Reactor and discover a process model.",
      inputs: %{
        "path" => %{type: :string, required?: true},
        "object_type" => %{type: :string, required?: false}
      },
      options: @discover_options
    },
    "process.discover_xes" => %{
      handler: :process_discover_xes,
      description: "Parse XES bytes and discover a process model through Reactor.",
      inputs: %{
        "xml" => %{type: :string, required?: true},
        "case_object_type" => %{type: :string, required?: false, default: "Case"}
      },
      options: @discover_options
    },
    "process.discover_xes_file" => %{
      handler: :process_discover_xes_file,
      description: "Read XES bytes inside Reactor and discover a process model.",
      inputs: %{
        "path" => %{type: :string, required?: true},
        "case_object_type" => %{type: :string, required?: false, default: "Case"}
      },
      options: @discover_options
    },
    "process.conform" => %{
      handler: :process_conform,
      description: "Compare an OCEL subject with a canonical DFG interchange model.",
      inputs: %{
        "subject" => %{type: :map, required?: true},
        "model" => %{type: :map, required?: true},
        "object_type" => %{type: :string, required?: false}
      },
      options: @engine_options
    },
    "process.simulate" => %{
      handler: :process_simulate,
      description: "Boundedly simulate a canonical DFG interchange model.",
      inputs: %{"model" => %{type: :map, required?: true}},
      options:
        Map.merge(@engine_options, %{
          "max_depth" => %{type: :integer, required?: false, default: 12},
          "max_paths" => %{type: :integer, required?: false, default: 128}
        })
    },
    "process.optimize" => %{
      handler: :process_optimize,
      description: "Construct non-actuating optimization candidates from an OCEL subject and model.",
      inputs: %{
        "subject" => %{type: :map, required?: true},
        "model" => %{type: :map, required?: true}
      },
      options: @engine_options
    },
    "process.plan" => %{
      handler: :process_plan,
      description: "Execute the admitted ex4pm-plan analytical planning engine.",
      inputs: %{"problem" => %{type: :map, required?: true}},
      options: %{}
    },
    "receipt.replay" => %{
      handler: :receipt_replay,
      description: "Replay-verify an existing receipt chain by exact receipt hash.",
      inputs: %{"hash" => %{type: :string, required?: true}},
      options: %{}
    }
  }

  @candidate_capabilities [
    %{
      id: "runtime.operate",
      standing: :unknown,
      admitted: false,
      reason: :requires_typed_runtime_plan_and_explicit_do_authority,
      boundary: :brce
    },
    %{
      id: "ash.mutate",
      standing: :unknown,
      admitted: false,
      reason: :generic_mutation_would_collapse_action_and_authority_boundaries,
      boundary: :brce
    },
    %{
      id: "external.wasm4pm",
      standing: :unknown,
      admitted: false,
      reason: :client_protocol_edge_preserved_not_observed_on_exact_subject,
      boundary: :jsonl_stdio
    },
    %{
      id: "external.pm4py",
      standing: :unknown,
      admitted: false,
      reason: :client_protocol_edge_preserved_not_observed_on_exact_subject,
      boundary: :jsonl_stdio
    }
  ]

  @transport_graph [
    %{id: :beam_in_process, standing: :unknown, implementation: :implemented, role: :native_client, protocol: "ex4pm.information/1"},
    %{id: :escript, standing: :unknown, implementation: :implemented, role: :human_and_process_client, protocol: "ex4pm.information/1"},
    %{id: :jsonl_stdio, standing: :unknown, implementation: :implemented, role: :machine_interop, protocol: "ex4pm.information/1"},
    %{id: :wasm4pm, standing: :unknown, implementation: :protocol_ready, role: :portable_wasm_client, protocol: "ex4pm.information/1"},
    %{id: :pm4py, standing: :unknown, implementation: :protocol_ready, role: :python_reference_client, protocol: "ex4pm.information/1"},
    %{id: :clap_noun_verb_any, standing: :unknown, implementation: :candidate, role: :generated_cli_client, protocol: "ex4pm.information/1"},
    %{id: :mcp, standing: :unknown, implementation: :candidate, role: :tool_projection, protocol: "ex4pm.information/1"}
  ]

  def public_capabilities do
    @capabilities
    |> Enum.map(fn {id, spec} ->
      %{
        id: id,
        description: spec.description,
        inputs: public_schema(spec.inputs),
        options: public_schema(spec.options),
        execution: :reactor,
        authority_domain: :observe
      }
    end)
    |> Enum.sort_by(& &1.id)
  end

  def candidate_capabilities, do: @candidate_capabilities
  def transport_graph, do: @transport_graph

  def describe(id) when is_binary(id) do
    case Map.fetch(@capabilities, id) do
      {:ok, spec} ->
        {:ok,
         %{
           id: id,
           description: spec.description,
           inputs: public_schema(spec.inputs),
           options: public_schema(spec.options),
           execution: :reactor,
           authority_domain: :observe
         }}

      :error ->
        case Enum.find(@candidate_capabilities, &(&1.id == id)) do
          nil ->
            {:error,
             Refusal.new(:unknown_capability, "capability is not registered",
               details: %{capability: id}
             )}

          candidate ->
            {:ok, candidate}
        end
    end
  end

  def admit(normalized) do
    case Map.fetch(@capabilities, normalized.capability) do
      :error ->
        {:error,
         Refusal.new(:unknown_capability, "capability is not admitted",
           details: %{capability: normalized.capability, admitted: Map.keys(@capabilities) |> Enum.sort()}
         )}

      {:ok, spec} ->
        with {:ok, input} <- validate_schema(normalized.input, spec.inputs, :input),
             {:ok, options} <- validate_schema(normalized.options, spec.options, :option),
             {:ok, context} <- validate_schema(normalized.context, @context_schema, :context),
             {:ok, resolved} <- resolve_special(normalized.capability, input) do
          {:ok,
           %Admitted{
             protocol: normalized.protocol,
             version: normalized.version,
             request_id: normalized.request_id,
             request_hash: normalized.request_hash,
             capability: normalized.capability,
             handler: spec.handler,
             input: input,
             context: context,
             options: options,
             limits: normalized.limits,
             resolved: resolved
           }}
        end
    end
  end

  defp resolve_special("ash.read", input) do
    AshCatalog.admit_read(input["resource"], input["action"], input["params"])
  end

  defp resolve_special(_capability, _input), do: {:ok, %{}}

  defp validate_schema(map, schema, kind) when is_map(map) do
    allowed = Map.keys(schema)

    unknown =
      map
      |> Map.keys()
      |> Enum.map(&key_string/1)
      |> Enum.reject(&(&1 in allowed))
      |> Enum.sort()

    if unknown != [] do
      {:error,
       Refusal.new(:"unknown_#{kind}", "request contains unsupported #{kind} fields",
         details: %{unknown: unknown, allowed: Enum.sort(allowed)}
       )}
    else
      schema
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.reduce_while({:ok, %{}}, fn {name, field}, {:ok, acc} ->
        case fetch_external(map, name) do
          :error ->
            cond do
              Map.has_key?(field, :default) ->
                {:cont, {:ok, Map.put(acc, name, field.default)}}

              field.required? ->
                {:halt,
                 {:error,
                  Refusal.new(:missing_required_input, "required request field is missing",
                    details: %{field: name, kind: kind}
                  )}}

              true ->
                {:cont, {:ok, acc}}
            end

          {:ok, value} ->
            case cast_field(name, field, value, kind) do
              {:ok, casted} -> {:cont, {:ok, Map.put(acc, name, casted)}}
              {:error, refusal} -> {:halt, {:error, refusal}}
            end
        end
      end)
    end
  end

  defp cast_field(name, field, value, kind) do
    constraints = Map.get(field, :constraints, [])

    case Ash.Type.cast_input(field.type, value, constraints) do
      {:ok, casted} ->
        case Ash.Type.apply_constraints(field.type, casted, constraints) do
          {:ok, constrained} ->
            validate_bounded_field(name, constrained, kind)

          {:error, reason} ->
            {:error,
             Refusal.new(:constraint_violation, "request field violates Ash.Type constraints",
               details: %{field: name, kind: kind, reason: inspect(reason)}
             )}
        end

      :error ->
        {:error,
         Refusal.new(:type_cast_failed, "request field cannot be cast to its Ash.Type",
           details: %{field: name, kind: kind, type: inspect(field.type)}
         )}

      {:error, reason} ->
        {:error,
         Refusal.new(:type_cast_failed, "request field cannot be cast to its Ash.Type",
           details: %{field: name, kind: kind, type: inspect(field.type), reason: inspect(reason)}
         )}
    end
  end

  defp validate_bounded_field("max_depth", value, _kind)
       when is_integer(value) and value >= 1 and value <= 256,
       do: {:ok, value}

  defp validate_bounded_field("max_paths", value, _kind)
       when is_integer(value) and value >= 1 and value <= 10_000,
       do: {:ok, value}

  defp validate_bounded_field("max_depth", value, kind),
    do: bounded_refusal("max_depth", value, kind, 1, 256)

  defp validate_bounded_field("max_paths", value, kind),
    do: bounded_refusal("max_paths", value, kind, 1, 10_000)

  defp validate_bounded_field(_name, value, _kind), do: {:ok, value}

  defp bounded_refusal(field, value, kind, minimum, maximum) do
    {:error,
     Refusal.new(:bounded_value_refused, "request field is outside the admitted bound",
       details: %{field: field, kind: kind, value: value, minimum: minimum, maximum: maximum}
     )}
  end

  defp public_schema(schema) do
    Map.new(schema, fn {name, field} ->
      {name,
       field
       |> Map.take([:type, :required?, :default, :constraints])
       |> Map.update(:type, nil, &inspect/1)}
    end)
  end

  defp fetch_external(map, name) do
    case Map.fetch(map, name) do
      {:ok, value} ->
        {:ok, value}

      :error ->
        atom =
          case name do
            "trace_id" -> :trace_id
            "tenant" -> :tenant
            "requester" -> :requester
            "metadata" -> :metadata
            "operation" -> :operation
            "resource" -> :resource
            "action" -> :action
            "params" -> :params
            "subject" -> :subject
            "xml" -> :xml
            "path" -> :path
            "object_type" -> :object_type
            "case_object_type" -> :case_object_type
            "model" -> :model
            "problem" -> :problem
            "hash" -> :hash
            "project" -> :project
            "engine" -> :engine
            "algorithm" -> :algorithm
            "max_depth" -> :max_depth
            "max_paths" -> :max_paths
            _ -> nil
          end

        if atom && Map.has_key?(map, atom), do: {:ok, Map.fetch!(map, atom)}, else: :error
    end
  end

  defp key_string(key) when is_binary(key), do: key
  defp key_string(key) when is_atom(key), do: Atom.to_string(key)
  defp key_string(key), do: inspect(key)
end
