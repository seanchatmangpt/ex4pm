defmodule Explore.TokenReplay do
  def replay(trace, model, start) do
    Enum.reduce_while(trace,{:ok,start},fn event,{:ok,state}->
      case Map.get(model,{state,event}) do nil->{:halt,{:refused,{:unexpected,event,state}}}; next->{:cont,{:ok,next}} end
    end)
  end
end
m=%{{:s0,:parse}=>:s1,{:s1,:admit}=>:s2,{:s2,:receipt}=>:s3}
{:ok,:s3}=Explore.TokenReplay.replay([:parse,:admit,:receipt],m,:s0)
{:refused,{:unexpected,:do,:s1}}=Explore.TokenReplay.replay([:parse,:do],m,:s0)
IO.inspect(%{candidate: :token_replay_conformance, standing: :alive})
