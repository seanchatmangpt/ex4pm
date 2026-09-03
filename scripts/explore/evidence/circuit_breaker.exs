defmodule Explore.CircuitBreaker do
  def step({:closed,n},:failure,t) when n+1>=t, do: {:open,0}
  def step({:closed,n},:failure,_), do: {:closed,n+1}
  def step({:closed,_},:success,_), do: {:closed,0}
  def step({:open,_},:probe,_), do: {:half_open,0}
  def step({:half_open,_},:success,_), do: {:closed,0}
  def step({:half_open,_},:failure,_), do: {:open,0}
end
{:open,0}=Enum.reduce([:failure,:failure,:failure],{:closed,0},&Explore.CircuitBreaker.step(&2,&1,3))
IO.inspect(%{candidate: :circuit_breaker, standing: :alive})
