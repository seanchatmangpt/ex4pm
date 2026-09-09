defmodule Ex4pmCore.CapsuleGraph.Independence.Standing do
  @moduledoc false

  @order [:alive, :partial_alive, :unknown, :unsupported, :blocked, :build_broken]

  def combine(standings) when is_list(standings) and standings != [] do
    Enum.max_by(standings, &rank/1)
  end

  def combine(_), do: :unknown

  def cap_positive(:alive), do: :partial_alive
  def cap_positive(other), do: other

  defp rank(standing) do
    case Enum.find_index(@order, &(&1 == standing)) do
      nil -> Enum.find_index(@order, &(&1 == :unknown))
      index -> index
    end
  end
end
