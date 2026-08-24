defmodule Ex4pm.Develop.Evidence.ReplayChain do
  def root(events) do
    Enum.reduce(events, <<0::256>>, fn event, acc -> :crypto.hash(:sha256, acc <> :erlang.term_to_binary(event)) end)
    |> Base.encode16(case: :lower)
  end
  def verify(events, expected), do: if(root(events)==expected, do: :ok, else: {:refused,:replay_drift})
end
