defmodule Explore.Replay do
  def digest(events), do: :crypto.hash(:sha256,:erlang.term_to_binary(events,[:deterministic]))
  def verify(events,digest), do: digest(events)==digest
end
e=[{:admit,:a},{:construct,:b},{:receipt,:c}]
d=Explore.Replay.digest(e)
true=Explore.Replay.verify(e,d)
false=Explore.Replay.verify(e++[{:do,:x}],d)
IO.inspect(%{candidate: :deterministic_replay, standing: :alive, digest: Base.encode16(d,case: :lower)})
