defmodule Ex4pm.Develop.Planner.SelectionReceipt do
  @moduledoc false
  def issue(subject, selected, evidence) when is_binary(subject) and is_list(selected) and is_map(evidence) do
    body = %{subject: subject, selected: Enum.sort(selected), evidence: evidence, authority: :select, actuation: false}
    digest = :crypto.hash(:sha256, :erlang.term_to_binary(body)) |> Base.encode16(case: :lower)
    Map.put(body, :digest, digest)
  end
end
