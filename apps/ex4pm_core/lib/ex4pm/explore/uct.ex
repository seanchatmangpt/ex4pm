defmodule Ex4pm.Explore.UCT do
  @moduledoc false
  def choose(children, parent_visits, c \\ 1.41421356237) do
    Enum.max_by(children, fn {_id, value, visits} ->
      if visits == 0, do: :infinity, else: value / visits + c * :math.sqrt(:math.log(max(parent_visits, 1)) / visits)
    end)
  end
end
