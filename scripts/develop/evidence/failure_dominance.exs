defmodule Ex4pm.Develop.Evidence.FailureDominance do
  @hard [:build_broken, :blocked]
  def standing(values) do
    cond do
      :build_broken in values -> :build_broken
      :blocked in values -> :blocked
      :unknown in values -> :unknown
      :partial_alive in values -> :partial_alive
      Enum.all?(values,&(&1==:alive)) -> :alive
      true -> :unknown
    end
  end
end
