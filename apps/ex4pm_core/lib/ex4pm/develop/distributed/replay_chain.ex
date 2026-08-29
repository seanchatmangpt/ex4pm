defmodule Ex4pm.Develop.Distributed.ReplayChain do
  @moduledoc false

  def root(entries) do
    entries
    |> Enum.map(&canonical/1)
    |> Enum.sort()
    |> Enum.join("\n")
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp canonical(term), do: :erlang.term_to_binary(term, [:deterministic])
end
