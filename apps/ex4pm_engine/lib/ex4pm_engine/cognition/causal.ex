defmodule Ex4pmEngine.Cognition.Causal do
  @moduledoc """
  Causal Discovery & Dependency Matrix Inference.
  Computes direct causal dependencies and confounding influences between activities from trace observations.
  """

  @doc """
  Computes the causal dependency matrix across unique activities in an event log.
  Uses heuristic net / inductive dependency score:
  `dep(a, b) = (|a > b| - |b > a|) / (|a > b| + |b > a| + 1)`
  """
  def infer_causal_dependencies(traces) when is_map(traces) or is_list(traces) do
    trace_list = if is_map(traces), do: Map.values(traces), else: traces

    # Extract directly-follows frequencies
    follows_counts =
      trace_list
      |> Enum.flat_map(fn events ->
        activities = Enum.map(events, fn ev -> if is_map(ev), do: ev.activity, else: ev end)

        activities
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [a, b] -> {a, b} end)
      end)
      |> Enum.frequencies()

    unique_activities =
      follows_counts
      |> Map.keys()
      |> Enum.flat_map(fn {a, b} -> [a, b] end)
      |> Enum.uniq()
      |> Enum.sort()

    # Calculate dependency scores
    matrix =
      for a <- unique_activities, b <- unique_activities, a != b, into: %{} do
        ab = Map.get(follows_counts, {a, b}, 0)
        ba = Map.get(follows_counts, {b, a}, 0)

        score =
          if ab + ba == 0 do
            0.0
          else
            Float.round((ab - ba) / (ab + ba + 1.0), 4)
          end

        {{a, b}, score}
      end

    # Filter strong causal edges (dependency score > threshold)
    strong_edges =
      matrix
      |> Enum.filter(fn {_edge, score} -> score >= 0.5 end)
      |> Map.new()

    %{
      activities: unique_activities,
      dependency_matrix: matrix,
      strong_causal_edges: strong_edges,
      edge_count: map_size(strong_edges)
    }
  end
end
