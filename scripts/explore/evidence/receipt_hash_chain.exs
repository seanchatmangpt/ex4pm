defmodule Explore.ReceiptHashChain do
  def append(prev,event), do: :crypto.hash(:sha256,prev<>:erlang.term_to_binary(event,[:deterministic]))
  def build(events), do: Enum.scan(events,<<0::256>>,fn e,prev->append(prev,e) end)
end
chain=Explore.ReceiptHashChain.build([{:pending,1},{:do,1},{:outcome,:ok}])
3=length(chain); true=Enum.uniq(chain)==chain
IO.inspect(%{candidate: :receipt_hash_chain, standing: :alive, tip: chain|>List.last()|>Base.encode16(case: :lower)})
