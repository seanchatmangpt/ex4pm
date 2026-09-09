defmodule Ex4pmCore.ProcessIR.Extractor.Evidence.Canonical do
  @moduledoc false

  def term(value) when is_map(value) do
    value
    |> Enum.map(fn {key, item} -> {to_string(key), term(item)} end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  def term(value) when is_list(value), do: Enum.map(value, &term/1)
  def term(value) when is_tuple(value), do: value |> Tuple.to_list() |> Enum.map(&term/1)
  def term(value) when is_atom(value), do: Atom.to_string(value)
  def term(value), do: value
end
