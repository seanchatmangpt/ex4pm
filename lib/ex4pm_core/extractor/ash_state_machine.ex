defmodule Ex4pmCore.ProcessIR.Extractor.AshStateMachine do
  @moduledoc """
  Extracts AshStateMachine state definitions, transitions, and transition guards
  directly into ProcessIR choice graphs and lifecycle constraints without AST walking.
  """

  alias Ex4pmCore.ProcessIR
  alias Ex4pmCore.ProcessIR.{Activity, Choice}

  @doc "Extracts state machine definitions from an Ash resource into a ProcessIR struct."
  def extract(resource, opts \\ []) when is_atom(resource) do
    res_name =
      resource
      |> Module.split()
      |> List.last()

    process_id = Keyword.get(opts, :id, "#{res_name}StateMachine")
    process_name = Keyword.get(opts, :name, "#{res_name} State Machine Process")

    states =
      if Code.ensure_loaded?(AshStateMachine.Info) and
           function_exported?(AshStateMachine.Info, :states, 1) do
        apply(AshStateMachine.Info, :states, [resource])
      else
        []
      end

    transitions =
      if Code.ensure_loaded?(AshStateMachine.Info) and
           function_exported?(AshStateMachine.Info, :transitions, 1) do
        apply(AshStateMachine.Info, :transitions, [resource])
      else
        []
      end

    initial_states =
      if Code.ensure_loaded?(AshStateMachine.Info) and
           function_exported?(AshStateMachine.Info, :initial_states, 1) do
        apply(AshStateMachine.Info, :initial_states, [resource])
      else
        []
      end

    activities =
      Enum.map(states, fn state ->
        st_str = to_string(state)

        %Activity{
          id: st_str,
          label: "State: #{st_str}",
          object_types: [res_name],
          lifecycle_states: [st_str],
          metadata: %{initial?: state in initial_states}
        }
      end)
      |> Enum.map(&{&1.id, &1})
      |> Map.new()

    # Map state transitions into Choice branches
    choice_branches =
      Enum.map(transitions, fn transition ->
        from_str = to_string(transition.from)
        to_str = to_string(transition.to)
        "#{from_str}->#{to_str}"
      end)

    choices =
      if choice_branches != [] do
        ch = %Choice{
          id: "#{res_name}_transitions",
          branches: choice_branches,
          type: :choice_graph,
          metadata: %{initial_states: Enum.map(initial_states, &to_string/1)}
        }

        %{ch.id => ch}
      else
        %{}
      end

    %ProcessIR{
      id: to_string(process_id),
      name: to_string(process_name),
      version: "1.0.0",
      activities: activities,
      choices: choices,
      metadata: %{source: :ash_state_machine_introspection, state_count: length(states)}
    }
  end
end
