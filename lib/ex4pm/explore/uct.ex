defmodule Ex4pm.Explore.UCT do
  @moduledoc false

  # Children are either {id, value, visits} tuples or %{value: _, visits: _} maps.
  def choose(children, parent_visits, c \\ :math.sqrt(2.0)) do
    Enum.max_by(children, fn child -> score(child, parent_visits, c) end)
  end

  def score({_id, value, visits}, parent_visits, c), do: score(%{value: value, visits: visits}, parent_visits, c)
  def score(%{visits: 0}, _parent_visits, _c), do: :infinity

  def score(%{value: value, visits: visits}, parent_visits, c) when visits > 0 do
    value / visits + c * :math.sqrt(:math.log(max(parent_visits, 1)) / visits)
  end
end
