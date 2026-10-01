defmodule Ex4pm.Explore.SemanticIdentity do
  @moduledoc false

  @spec canonical(term()) :: binary()
  def canonical(term), do: term |> normalize() |> :erlang.term_to_binary([:deterministic])

  @spec sha256(term()) :: String.t()
  def sha256(term) do
    term |> canonical() |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)
  end

  defp normalize(map) when is_map(map), do: map |> Enum.map(fn {k, v} -> {normalize(k), normalize(v)} end) |> Enum.sort()
  defp normalize(list) when is_list(list), do: Enum.map(list, &normalize/1)
  defp normalize(tuple) when is_tuple(tuple), do: tuple |> Tuple.to_list() |> Enum.map(&normalize/1) |> List.to_tuple()
  defp normalize(value), do: value
end
