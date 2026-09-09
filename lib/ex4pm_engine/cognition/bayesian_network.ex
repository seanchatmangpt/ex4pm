defmodule Ex4pmEngine.Cognition.BayesianNetwork do
  @moduledoc """
  Discrete Bayesian Network inference engine supporting exact marginalization,
  conditional belief updates, and variable elimination over directed acyclic graphs.
  """

  @enforce_keys [:nodes, :cpts]
  defstruct [:nodes, :cpts, metadata: %{}]

  @type t :: %__MODULE__{
          nodes: [String.t()],
          cpts: %{optional(String.t()) => map()},
          metadata: map()
        }

  @doc "Constructs a new Bayesian Network with nodes and conditional probability tables."
  def new(nodes, cpts, metadata \\ %{}) when is_list(nodes) and is_map(cpts) do
    %__MODULE__{
      nodes: Enum.map(nodes, &to_string/1),
      cpts: cpts,
      metadata: metadata
    }
  end

  @doc """
  Performs exact inference to compute the posterior distribution P(Query | Evidence).
  `evidence` is a map of `{node_name => observed_value}`.
  """
  def infer(%__MODULE__{} = bn, query_var, evidence \\ %{}) do
    query_str = to_string(query_var)
    evidence_map = Map.new(evidence, fn {k, v} -> {to_string(k), to_string(v)} end)

    # Enumerate all possible joint assignments consistent with evidence
    non_evidence_vars = Enum.reject(bn.nodes, &Map.has_key?(evidence_map, &1))

    possible_values =
      Map.new(bn.nodes, fn node ->
        cpt = Map.fetch!(bn.cpts, node)
        values = extract_node_domain(cpt)
        {node, values}
      end)

    query_domain = Map.get(possible_values, query_str, ["true", "false"])

    unnormalized =
      Enum.map(query_domain, fn q_val ->
        fixed_assignment = Map.put(evidence_map, query_str, q_val)
        hidden_vars = List.delete(non_evidence_vars, query_str)
        prob_sum = enumerate_all_hidden(bn, hidden_vars, fixed_assignment, possible_values)
        {q_val, prob_sum}
      end)
      |> Map.new()

    total_mass = Enum.reduce(Map.values(unnormalized), 0.0, &(&1 + &2))

    if total_mass > 0.0 do
      posterior =
        Map.new(unnormalized, fn {val, prob} ->
          {val, Float.round(prob / total_mass, 4)}
        end)

      {:ok, %{query: query_str, evidence: evidence_map, distribution: posterior}}
    else
      {:error, :impossible_evidence}
    end
  end

  defp enumerate_all_hidden(bn, [], current_assignment, _possible_values) do
    # Base case: compute joint probability of full assignment
    joint_probability(bn, current_assignment)
  end

  defp enumerate_all_hidden(bn, [var | rest], current_assignment, possible_values) do
    domain = Map.fetch!(possible_values, var)

    Enum.reduce(domain, 0.0, fn val, acc ->
      new_assignment = Map.put(current_assignment, var, val)
      acc + enumerate_all_hidden(bn, rest, new_assignment, possible_values)
    end)
  end

  defp joint_probability(bn, assignment) do
    Enum.reduce(bn.nodes, 1.0, fn node, acc ->
      cpt = Map.fetch!(bn.cpts, node)
      p = cpt_lookup(cpt, node, assignment)
      acc * p
    end)
  end

  defp cpt_lookup(cpt, node, assignment) do
    node_val = Map.get(assignment, node)
    first_key = Map.keys(cpt) |> List.first()

    cond do
      is_binary(first_key) and is_number(Map.get(cpt, first_key)) ->
        Map.get(cpt, node_val, 0.0)

      true ->
        matching_entry =
          Enum.find_value(cpt, fn {parent_pattern, outcome_map} ->
            if matches_parents?(parent_pattern, assignment) do
              Map.get(outcome_map, node_val, 0.0)
            end
          end)

        matching_entry || 0.0
    end
  end

  defp matches_parents?(pattern, assignment) when is_map(pattern) do
    Enum.all?(pattern, fn {p_k, p_v} -> Map.get(assignment, to_string(p_k)) == to_string(p_v) end)
  end

  defp matches_parents?(_, _), do: true

  defp extract_node_domain(cpt) when is_map(cpt) do
    keys = Map.keys(cpt)

    if Enum.all?(keys, &is_binary/1) and is_number(Map.get(cpt, hd(keys))) do
      keys
    else
      ["true", "false"]
    end
  end
end
