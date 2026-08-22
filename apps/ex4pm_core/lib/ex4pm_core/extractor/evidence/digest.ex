defmodule Ex4pmCore.ProcessIR.Extractor.Evidence.Digest do
  @moduledoc false

  alias Ex4pmCore.ProcessIR.Extractor.Evidence.Canonical

  def of(term) do
    term
    |> Canonical.term()
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
