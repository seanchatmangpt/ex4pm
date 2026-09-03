defmodule Explore.ConstraintFilter do
  def feasible(candidates, constraints) do
    Enum.filter(candidates,fn {_id,attrs}->Enum.all?(constraints,fn {k,pred}->pred.(Map.fetch!(attrs,k)) end) end)
  end
end
c=[a: %{latency: 8,risk: 1}, b: %{latency: 20,risk: 0}, c: %{latency: 5,risk: 3}]
f=Explore.ConstraintFilter.feasible(c,[latency: &(&1<=10),risk: &(&1<=1)])
[a: %{latency: 8,risk: 1}]=f
IO.inspect(%{candidate: :hard_constraint_filter, standing: :alive})
