defmodule Ex4pm.Domain.ProcessGraphProjector do
  @moduledoc """
  Real OTP `:digraph`/`:digraph_utils`-backed topology projection over an
  `Ex4pm.Domain.ProcessModel` record's `:model` map. Zero new hex deps.

  Consumable two ways: directly via `topology/1` (a plain map -> map
  function), or wired as an Ash module calculation on a resource (see
  `Ex4pm.Domain.ProcessModel`'s `calculate :topology` declaration).
  """

  use Ash.Resource.Calculation

  @doc """
  Projects `%{"nodes" => [...], "edges" => [[from, to], ...]}` (or the atom-
  keyed equivalent) into `%{topsort: [...] | nil, components: [[...], ...]}`
  using a real, temporary `:digraph.graph()`.

  `topsort` is `nil` when the graph has a real cycle (honest -- `:digraph`
  itself returns `false` for `:topsort/1` on a cyclic graph, not a crash).
  """
  @spec topology(map) :: %{topsort: [term] | nil, components: [[term]]}
  def topology(model) when is_map(model) do
    nodes = Map.get(model, "nodes") || Map.get(model, :nodes) || []
    edges = Map.get(model, "edges") || Map.get(model, :edges) || []

    graph = :digraph.new()

    try do
      Enum.each(nodes, &:digraph.add_vertex(graph, &1))

      Enum.each(edges, fn
        [from, to] -> ensure_edge(graph, from, to)
        {from, to} -> ensure_edge(graph, from, to)
      end)

      topsort =
        case :digraph_utils.topsort(graph) do
          false -> nil
          order -> order
        end

      components = :digraph_utils.components(graph)

      %{topsort: topsort, components: components}
    after
      :digraph.delete(graph)
    end
  end

  defp ensure_edge(graph, from, to) do
    :digraph.add_vertex(graph, from)
    :digraph.add_vertex(graph, to)
    :digraph.add_edge(graph, from, to)
  end

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, fn record -> topology(Map.get(record, :model) || %{}) end)
  end
end
