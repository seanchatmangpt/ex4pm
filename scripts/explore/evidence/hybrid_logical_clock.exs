defmodule Explore.HLC do
  def send({wall,counter},now) when now>wall, do: {now,0}
  def send({wall,counter},_now), do: {wall,counter+1}
  def recv({wall,counter},{rwall,rcounter},now) do
    maxwall=max(max(wall,rwall),now)
    next=cond do maxwall==wall and maxwall==rwall->max(counter,rcounter)+1; maxwall==wall->counter+1; maxwall==rwall->rcounter+1; true->0 end
    {maxwall,next}
  end
end
{10,1}=Explore.HLC.send({10,0},9)
{12,4}=Explore.HLC.recv({10,1},{12,3},11)
IO.inspect(%{candidate: :hybrid_logical_clock, standing: :alive})
