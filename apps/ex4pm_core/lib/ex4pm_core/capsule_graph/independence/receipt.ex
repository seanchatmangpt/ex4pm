defmodule Ex4pmCore.CapsuleGraph.Independence.Receipt do
  @moduledoc false
  alias Ex4pmCore.CapsuleGraph.Digest

  def issue(attempt_id, standing, diversity, cluster_count, blockers, strategy, authority \\ :construct) do
    body = %{
      attempt_id: attempt_id,
      standing: standing,
      diversity: diversity,
      cluster_count: cluster_count,
      blockers: Enum.sort(blockers),
      strategy: strategy,
      authority: authority,
      actuation_performed: false
    }

    %{schema: "ex4pm.capsule-independence/v1", body: body, digest: Digest.sha256(body)}
  end

  def replay(%{schema: "ex4pm.capsule-independence/v1", body: body, digest: digest}) do
    body.actuation_performed == false and
      body.authority in [:observe, :select, :construct, :verify] and
      Digest.sha256(body) == digest
  end

  def replay(_), do: false
end
