defmodule Ex4pm.Develop.Semantic.SelectionReceipt do
  @moduledoc false
  def issue(subject, candidates, laws) do
    body = %{subject: subject, candidates: Enum.sort(candidates), laws: Enum.sort(laws), authority: :select, actuation: false}
    Map.put(body, :digest, :crypto.hash(:sha256, :erlang.term_to_binary(body)) |> Base.encode16(case: :lower))
  end
end
