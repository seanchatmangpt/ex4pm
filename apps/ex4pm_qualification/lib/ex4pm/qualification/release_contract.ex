defmodule Ex4pm.Qualification.ReleaseContract do
  @moduledoc "Executable release obligations for the dated ex4pm qualification crown."

  @version "26.8.23"
  @obligations [
    %{id: :powl_correspondence, authority: :repository, evidence: :semantic_court},
    %{id: :compiler_refinement, authority: :repository, evidence: :reactor_refinement},
    %{id: :exact_head_ci, authority: :repository, evidence: :github_exact_head},
    %{id: :planner_oci, authority: :repository, evidence: :planner_capsule},
    %{id: :reference_rails, authority: :repository, evidence: :rail_court},
    %{id: :ambiguity_closure, authority: :repository, evidence: :distributed_receipts},
    %{id: :independent_verifier, authority: :repository, evidence: :python_recomputation},
    %{id: :sabotage_court, authority: :repository, evidence: :falsifier_ledger},
    %{id: :global_topology, authority: :external_infrastructure, evidence: :topology_attestations},
    %{id: :hex_package, authority: :release, evidence: :package_inspection}
  ]

  @states [:unknown, :partial_alive, :alive, :blocked, :build_broken, :unsupported, :refused]

  def version, do: @version
  def obligations, do: @obligations

  def evaluate(evidence) when is_map(evidence) do
    results =
      Map.new(@obligations, fn obligation ->
        state = evidence |> fetch(obligation.id) |> normalize_state()
        {obligation.id, Map.put(obligation, :state, state)}
      end)

    blocked = ids_with(results, [:blocked, :build_broken, :refused])
    missing = ids_with(results, [:unknown, :partial_alive, :unsupported])

    standing =
      cond do
        blocked != [] -> :blocked
        missing == [] -> :alive
        true -> :partial_alive
      end

    %{
      version: @version,
      standing: standing,
      obligations: results,
      blocked: blocked,
      missing: missing,
      external_authority:
        @obligations
        |> Enum.filter(&(&1.authority == :external_infrastructure))
        |> Enum.map(& &1.id)
    }
  end

  defp ids_with(results, states) do
    results
    |> Enum.filter(fn {_id, obligation} -> obligation.state in states end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.sort()
  end

  defp fetch(map, key), do: Map.get(map, key) || Map.get(map, Atom.to_string(key))

  defp normalize_state(value) when value in @states, do: value
  defp normalize_state(value) when is_binary(value) do
    case String.upcase(value) do
      "UNKNOWN" -> :unknown
      "PARTIAL_ALIVE" -> :partial_alive
      "ALIVE" -> :alive
      "BLOCKED" -> :blocked
      "BUILD_BROKEN" -> :build_broken
      "UNSUPPORTED" -> :unsupported
      "REFUSED" -> :refused
      _ -> :unknown
    end
  end

  defp normalize_state(_), do: :unknown
end
