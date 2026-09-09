defmodule Ex4pmCore.CapsuleGraph.Standing do
  @moduledoc false

  @outcomes [:pass, :fail, :pending, :unknown, :unsupported]

  def from_outcomes([]), do: :unknown

  def from_outcomes(outcomes) when is_list(outcomes) do
    cond do
      Enum.any?(outcomes, &(&1 not in @outcomes)) -> {:refused, :invalid_evidence_outcome}
      :fail in outcomes -> :build_broken
      :pending in outcomes -> :unknown
      :unknown in outcomes -> :unknown
      Enum.all?(outcomes, &(&1 == :unsupported)) -> :unsupported
      :pass in outcomes -> :partial_alive
      true -> :unknown
    end
  end

  def outcomes, do: @outcomes
end
