defmodule Ex4pm.Explore.Candidate do
  @moduledoc false
  @enforce_keys [:id, :semantic_identity, :methodology, :implementation]
  defstruct [:id, :semantic_identity, :methodology, :implementation, capabilities: MapSet.new(), evidence: [], status: :UNKNOWN]

  @statuses [:UNKNOWN, :PARTIAL_ALIVE, :ALIVE, :BLOCKED, :BUILD_BROKEN, :UNSUPPORTED, :REFUSED]

  def new(attrs) when is_map(attrs) do
    candidate = struct!(__MODULE__, attrs)
    if candidate.status in @statuses, do: {:ok, candidate}, else: {:error, {:invalid_status, candidate.status}}
  end

  def admit(%__MODULE__{} = candidate, evidence) when is_list(evidence) and evidence != [] do
    %{candidate | evidence: candidate.evidence ++ evidence, status: :PARTIAL_ALIVE}
  end
end
