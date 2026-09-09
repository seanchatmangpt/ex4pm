defmodule Ex4pmEngine.Beam.SoundnessGraph do
  @moduledoc """
  Real `:digraph`-backed reachability/cycle checks over a POWL-shaped process
  model, expressed as `Ex4pm.Standing`-compatible outcomes.

  Deliberately built on OTP's own `:digraph`/`:digraph_utils` (no new hex
  dependency) rather than a third-party graph library -- the same real
  collaborator `Ex4pmDomain.ProcessGraphProjector` uses, so both P0 modules
  share one proven graph substrate.

  Input shape: `%{start: term, arcs: [{term, term}]}` where `arcs` are
  directed `{from, to}` pairs over process-model node identifiers.
  """

  @doc "Builds a real, temporary `:digraph.graph()` from a POWL-shaped arc list. Caller owns lifecycle."
  @spec build(%{arcs: [{term, term}]}) :: :digraph.graph()
  def build(%{arcs: arcs}) do
    graph = :digraph.new()

    arcs
    |> Enum.reduce(MapSet.new(), fn {from, to}, seen ->
      seen
      |> maybe_add_vertex(graph, from)
      |> maybe_add_vertex(graph, to)
    end)

    Enum.each(arcs, fn {from, to} -> :digraph.add_edge(graph, from, to) end)

    graph
  end

  defp maybe_add_vertex(seen, graph, vertex) do
    if MapSet.member?(seen, vertex) do
      seen
    else
      :digraph.add_vertex(graph, vertex)
      MapSet.put(seen, vertex)
    end
  end

  @doc """
  Checks a POWL-shaped model for cycles and unreachable-from-start vertices,
  returning a real `Ex4pm.Standing`-compatible `{standing, detail}` tuple.

  `{:alive, %{vertices: [...]}}` when acyclic and every vertex is reachable
  from `start`; `{:blocked, {:cycle_detected, cycle}}` when a real cycle
  exists; `{:blocked, {:unreachable_vertices, [...]}}` when some vertex has no
  path from `start`.
  """
  @spec check(%{start: term, arcs: [{term, term}]}) ::
          {:alive, %{vertices: [term]}}
          | {:blocked, {:cycle_detected, [term]}}
          | {:blocked, {:unreachable_vertices, [term]}}
  def check(%{start: start} = powl_model) do
    graph = build(powl_model)

    try do
      case find_cycle(graph) do
        {:ok, cycle} ->
          {:blocked, {:cycle_detected, cycle}}

        :none ->
          all_vertices = :digraph.vertices(graph)
          reachable = :digraph_utils.reachable([start], graph)
          unreachable = all_vertices -- reachable

          if unreachable == [] do
            {:alive, %{vertices: all_vertices}}
          else
            {:blocked, {:unreachable_vertices, unreachable}}
          end
      end
    after
      :digraph.delete(graph)
    end
  end

  defp find_cycle(graph) do
    graph
    |> :digraph.vertices()
    |> Enum.find_value(:none, fn vertex ->
      case :digraph.get_cycle(graph, vertex) do
        false -> nil
        cycle -> {:ok, cycle}
      end
    end)
  end
end
