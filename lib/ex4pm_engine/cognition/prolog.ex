defmodule Ex4pmEngine.Cognition.Prolog do
  @moduledoc """
  Horn-clause backward chaining resolution engine with Robinson first-order term unification.
  Provides native BEAM logic programming execution for rules, invariants, and ontology deductions.
  """

  @enforce_keys [:clauses]
  defstruct [:clauses, metadata: %{}]

  @type clause :: {:fact, tuple()} | {:rule, tuple(), [tuple()]}
  @type t :: %__MODULE__{
          clauses: [clause()],
          metadata: map()
        }

  @doc "Constructs a new Prolog knowledge base from clauses."
  def new(clauses \\ [], metadata \\ %{}) do
    %__MODULE__{
      clauses: clauses,
      metadata: metadata
    }
  end

  @doc "Asserts a fact into the knowledge base."
  def assert_fact(%__MODULE__{} = kb, fact) when is_tuple(fact) do
    %{kb | clauses: [{:fact, fact} | kb.clauses]}
  end

  @doc "Asserts a Horn clause rule: Head :- Body1, Body2, ..."
  def assert_rule(%__MODULE__{} = kb, head, body) when is_tuple(head) and is_list(body) do
    %{kb | clauses: [{:rule, head, body} | kb.clauses]}
  end

  @doc "Evaluates a query against the knowledge base, returning all satisfying variable bindings."
  def query(%__MODULE__{} = kb, goals) when is_list(goals) do
    solve(goals, %{}, kb.clauses, 0)
  end

  def query(%__MODULE__{} = kb, goal) when is_tuple(goal) do
    query(kb, [goal])
  end

  # SLD Resolution
  defp solve([], env, _clauses, _depth), do: [env]

  defp solve(_goals, _env, _clauses, depth) when depth > 100 do
    # Depth bound to prevent infinite recursion on left-recursive rules
    []
  end

  defp solve([goal | rest_goals], env, clauses, depth) do
    subst_goal = apply_bindings(goal, env)

    Enum.flat_map(clauses, fn
      {:fact, fact} ->
        renamed_fact = rename_vars(fact, depth)

        case unify(subst_goal, renamed_fact, env) do
          {:ok, new_env} ->
            solve(rest_goals, new_env, clauses, depth + 1)

          :error ->
            []
        end

      {:rule, head, body} ->
        renamed_head = rename_vars(head, depth)
        renamed_body = Enum.map(body, &rename_vars(&1, depth))

        case unify(subst_goal, renamed_head, env) do
          {:ok, new_env} ->
            solve(renamed_body ++ rest_goals, new_env, clauses, depth + 1)

          :error ->
            []
        end
    end)
  end

  @doc "Robinson First-Order Term Unification."
  def unify(t1, t2, env \\ %{})

  def unify(t1, t2, env) do
    t1 = resolve_var(t1, env)
    t2 = resolve_var(t2, env)

    cond do
      t1 == t2 ->
        {:ok, env}

      is_var(t1) ->
        {:ok, Map.put(env, t1, t2)}

      is_var(t2) ->
        {:ok, Map.put(env, t2, t1)}

      is_tuple(t1) and is_tuple(t2) and tuple_size(t1) == tuple_size(t2) ->
        l1 = Tuple.to_list(t1)
        l2 = Tuple.to_list(t2)

        Enum.reduce_while(Enum.zip(l1, l2), {:ok, env}, fn {x, y}, {:ok, cur_env} ->
          case unify(x, y, cur_env) do
            {:ok, next_env} -> {:cont, {:ok, next_env}}
            :error -> {:halt, :error}
          end
        end)

      is_list(t1) and is_list(t2) and length(t1) == length(t2) ->
        Enum.reduce_while(Enum.zip(t1, t2), {:ok, env}, fn {x, y}, {:ok, cur_env} ->
          case unify(x, y, cur_env) do
            {:ok, next_env} -> {:cont, {:ok, next_env}}
            :error -> {:halt, :error}
          end
        end)

      true ->
        :error
    end
  end

  def is_var(atom) when is_atom(atom) do
    str = Atom.to_string(atom)
    first_char = String.first(str)
    first_char >= "A" and first_char <= "Z"
  end

  def is_var(_), do: false

  defp resolve_var(v, env) when is_atom(v) do
    if is_var(v) and Map.has_key?(env, v) do
      resolve_var(Map.get(env, v), env)
    else
      v
    end
  end

  defp resolve_var(term, _env), do: term

  defp apply_bindings(term, env) do
    cond do
      is_var(term) ->
        case Map.get(env, term) do
          nil -> term
          bound -> apply_bindings(bound, env)
        end

      is_tuple(term) ->
        Tuple.to_list(term)
        |> Enum.map(&apply_bindings(&1, env))
        |> List.to_tuple()

      is_list(term) ->
        Enum.map(term, &apply_bindings(&1, env))

      true ->
        term
    end
  end

  defp rename_vars(term, depth) do
    cond do
      is_var(term) ->
        String.to_atom("#{term}_#{depth}")

      is_tuple(term) ->
        Tuple.to_list(term)
        |> Enum.map(&rename_vars(&1, depth))
        |> List.to_tuple()

      is_list(term) ->
        Enum.map(term, &rename_vars(&1, depth))

      true ->
        term
    end
  end
end
