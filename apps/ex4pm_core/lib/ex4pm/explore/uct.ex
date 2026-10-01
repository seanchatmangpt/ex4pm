defmodule Ex4pm.Explore.UCT do
  @moduledoc false

  def score(%{visits: 0}, _parent_visits, _c), do: :infinity
  def score(%{value: value, visits: visits}, parent_visits, c) when visits > 0 and parent_visits > 0 do
    value / visits + c * :math.sqrt(:math.log(parent_visits) / visits)
  end

  def choose(children, parent_visits, c \\ :math.sqrt(2.0)) do
    Enum.max_by(children, fn child -> score(child, parent_visits, c) end)
  end
end
