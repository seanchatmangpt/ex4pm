defmodule Explore.MCTSRollout do
  def evaluate(actions, rollout) do
    actions |> Enum.map(fn a->{a,Enum.sum(for seed<-0..31, do: rollout.(a,seed))/32} end) |> Enum.max_by(&elem(&1,1))
  end
end
rollout=fn :safe,_seed->0.6; :risky,seed->if rem(seed,4)==0, do: 1.0, else: 0.3 end end
{:safe,score}=Explore.MCTSRollout.evaluate([:safe,:risky],rollout)
true = score > 0.59
IO.inspect(%{candidate: :mcts_rollout_reference, standing: :alive, selected: :safe})
