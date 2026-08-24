defmodule Ex4pm.Explore.ConsistentHash do
  @moduledoc false
  def ring(nodes) do
    nodes |> Enum.map(&{:erlang.phash2(&1, 4_294_967_295), &1}) |> Enum.sort()
  end

  def locate([], _key), do: nil
  def locate(ring, key) do
    h = :erlang.phash2(key, 4_294_967_295)
    case Enum.find(ring, fn {point, _} -> point >= h end) do
      nil -> ring |> hd() |> elem(1)
      {_point, node} -> node
    end
  end
end
