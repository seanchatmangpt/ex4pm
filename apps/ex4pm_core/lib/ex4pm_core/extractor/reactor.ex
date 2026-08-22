defmodule Ex4pmCore.ProcessIR.Extractor.Reactor do
  @moduledoc """
  Extracts Reactor saga and step definitions into canonical ProcessIR partial orders.

  Introspects step DAGs, wait_for dependencies, undo/compensate hooks, and data inputs,
  mapping Reactor steps to ProcessIR.Activity and execution dependencies to ProcessIR.PartialOrder.
  """

  alias Ex4pmCore.ProcessIR
  alias Ex4pmCore.ProcessIR.{Activity, PartialOrder}

  @doc "Extracts a Reactor module into a ProcessIR struct."
  def extract(reactor_module, opts \\ []) when is_atom(reactor_module) do
    Code.ensure_loaded(reactor_module)
    process_id = Keyword.get(opts, :id, reactor_name(reactor_module))
    process_name = Keyword.get(opts, :name, "Reactor Saga #{reactor_name(reactor_module)}")

    steps = extract_steps(reactor_module)

    activities =
      Enum.map(steps, fn step ->
        step_name = Map.get(step, :name)
        step_id = to_string(step_name)

        impl = Map.get(step, :impl)
        Code.ensure_loaded(impl)

        has_undo? = is_tuple(impl) or (is_atom(impl) and function_exported?(impl, :undo, 3))

        has_compensate? =
          is_tuple(impl) or (is_atom(impl) and function_exported?(impl, :compensate, 4))

        %Activity{
          id: step_id,
          label: "Step #{step_name}",
          lifecycle_states: ["create", "start", "complete", "compensate", "undo"],
          attributes: %{
            impl: inspect(impl),
            has_undo?: has_undo?,
            has_compensate?: has_compensate?,
            max_retries: Map.get(step, :max_retries, 0)
          },
          metadata: %{reactor: inspect(reactor_module), step_name: step_name}
        }
      end)
      |> Enum.map(&{&1.id, &1})
      |> Map.new()

    # Extract DAG dependencies into PartialOrder edges
    edges =
      Enum.flat_map(steps, fn step ->
        target = to_string(Map.get(step, :name))

        # Dependencies from wait_for
        wait_fors =
          Map.get(step, :wait_for, [])
          |> List.wrap()
          |> Enum.map(&to_string/1)

        # Dependencies from argument results
        arg_deps =
          Map.get(step, :arguments, [])
          |> List.wrap()
          |> Enum.flat_map(fn arg ->
            case Map.get(arg, :source) do
              {:result, step_name} -> [to_string(step_name)]
              _ -> []
            end
          end)

        (wait_fors ++ arg_deps)
        |> Enum.uniq()
        |> Enum.map(fn source -> {source, target} end)
      end)

    node_ids = Enum.map(steps, &to_string(Map.get(&1, :name)))

    partial_orders =
      if node_ids != [] do
        po = %PartialOrder{
          id: "#{process_id}_dag",
          nodes: node_ids,
          edges: edges,
          metadata: %{source: :reactor_dag}
        }

        %{po.id => po}
      else
        %{}
      end

    %ProcessIR{
      id: to_string(process_id),
      name: to_string(process_name),
      version: "1.0.0",
      activities: activities,
      partial_orders: partial_orders,
      root: if(node_ids != [], do: "#{process_id}_dag", else: nil),
      metadata: %{source: :reactor_introspection, step_count: length(steps)}
    }
  end

  defp extract_steps(reactor_module) do
    cond do
      function_exported?(reactor_module, :reactor, 0) ->
        try do
          case reactor_module.reactor() do
            %{steps: s} when is_list(s) -> s
            _ -> []
          end
        rescue
          _ -> []
        end

      Code.ensure_loaded?(Reactor.Info) and function_exported?(Reactor.Info, :steps, 1) ->
        try do
          apply(Reactor.Info, :steps, [reactor_module])
        rescue
          _ -> []
        end

      Code.ensure_loaded?(Spark.Dsl.Extension) and
          function_exported?(Spark.Dsl.Extension, :get_entities, 2) ->
        try do
          apply(Spark.Dsl.Extension, :get_entities, [reactor_module, [:steps]])
        rescue
          _ -> []
        end

      true ->
        []
    end
  end

  defp reactor_name(module) do
    module
    |> Module.split()
    |> List.last()
  end
end
