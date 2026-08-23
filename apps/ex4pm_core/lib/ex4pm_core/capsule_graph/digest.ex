defmodule Ex4pmCore.CapsuleGraph.Digest do
  @moduledoc false

  def sha256(term) do
    term
    |> canonicalize()
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  def canonicalize(%_{} = struct), do: struct |> Map.from_struct() |> canonicalize()

  def canonicalize(map) when is_map(map) do
    map
    |> Enum.map(fn {key, value} -> {canonicalize(key), canonicalize(value)} end)
    |> Enum.sort()
  end

  def canonicalize(list) when is_list(list), do: Enum.map(list, &canonicalize/1)

  def canonicalize(tuple) when is_tuple(tuple),
    do: tuple |> Tuple.to_list() |> Enum.map(&canonicalize/1) |> List.to_tuple()

  def canonicalize(value), do: value
end
