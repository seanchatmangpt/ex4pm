defmodule Ex4pm.Develop.Distributed.ConsistentRing do
  @moduledoc false
  def owner(nodes, key) when is_list(nodes) and nodes != [] do
    ordered = Enum.sort(nodes)
    Enum.at(ordered, rem(:erlang.phash2(key), length(ordered)))
  end
  def owner([], _key), do: {:error, :empty_ring}
end
