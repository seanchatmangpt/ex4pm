defmodule Ex4pmEngine.Cognition.Planner do
  @moduledoc """
  STRIPS means-ends and Hierarchical Task Network (HTN) action planner.
  Constructs sound plans to transition from initial state to goal state over state transitions.
  """

  @enforce_keys [:actions]
  defstruct [:actions, metadata: %{}]

  defmodule Action do
    @moduledoc "A STRIPS action operator with pre-conditions, add-list, and delete-list."
    @enforce_keys [:name, :preconditions, :add_list, :delete_list]
    defstruct [:name, :preconditions, :add_list, :delete_list, cost: 1.0, metadata: %{}]
  end

  @doc "Constructs a new planner from a list of action operators."
  def new(actions, metadata \\ %{}) when is_list(actions) do
    %__MODULE__{
      actions: actions,
      metadata: metadata
    }
  end

  @doc """
  Solves for a valid plan sequence transforming `initial_state` (Set/List of facts)
  into a state satisfying `goal_state` (Set/List of required facts).
  """
  def plan(%__MODULE__{} = planner, initial_state, goal_state, opts \\ []) do
    init_set = MapSet.new(Enum.map(initial_state, &to_string/1))
    goal_set = MapSet.new(Enum.map(goal_state, &to_string/1))
    max_depth = Keyword.get(opts, :max_depth, 20)

    # Breadth-first / A* search in state space
    queue = :queue.from_list([{init_set, [], 0.0}])
    visited = MapSet.new([init_set])

    search(queue, visited, goal_set, planner.actions, max_depth)
  end

  defp search(queue, visited, goal_set, actions, max_depth) do
    if :queue.is_empty(queue) do
      {:error, :no_plan_found}
    else
      {{:value, {current_state, plan_acc, cost_acc}}, rest_q} = :queue.out(queue)

      if MapSet.subset?(goal_set, current_state) do
        {:ok,
         %{
           plan: Enum.reverse(plan_acc),
           total_cost: cost_acc,
           final_state: MapSet.to_list(current_state)
         }}
      else
        if length(plan_acc) >= max_depth do
          search(rest_q, visited, goal_set, actions, max_depth)
        else
          valid_expansions =
            for action <- actions,
                MapSet.subset?(
                  MapSet.new(Enum.map(action.preconditions, &to_string/1)),
                  current_state
                ) do
              new_state =
                current_state
                |> MapSet.difference(MapSet.new(Enum.map(action.delete_list, &to_string/1)))
                |> MapSet.union(MapSet.new(Enum.map(action.add_list, &to_string/1)))

              {new_state, action.name, action.cost || 1.0}
            end

          {new_q, new_visited} =
            Enum.reduce(valid_expansions, {rest_q, visited}, fn {next_state, act_name, act_cost},
                                                                {q, v} ->
              if MapSet.member?(v, next_state) do
                {q, v}
              else
                {:queue.in({next_state, [act_name | plan_acc], cost_acc + act_cost}, q),
                 MapSet.put(v, next_state)}
              end
            end)

          search(new_q, new_visited, goal_set, actions, max_depth)
        end
      end
    end
  end
end
