defmodule Ex4pm.Develop.Search.PathCertificate do
  @moduledoc false
  def certify(path, edge_cost) when is_list(path) do
    cost = path |> Enum.chunk_every(2, 1, :discard) |> Enum.reduce_while(0, fn [a,b], acc ->
      case edge_cost.(a,b) do
        c when is_number(c) and c >= 0 -> {:cont, acc + c}
        _ -> {:halt, :invalid}
      end
    end)
    if cost == :invalid, do: {:error, :invalid_path_edge}, else: {:ok, %{path: path, cost: cost}}
  end
end
