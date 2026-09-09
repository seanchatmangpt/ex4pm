defmodule Ex4pmCore.CapsuleGraph.Admission do
  @moduledoc false

  alias Ex4pmCore.CapsuleGraph.{Candidate, Evidence, Subject}

  def admit(%Candidate{} = candidate) do
    with :ok <- admit_evidence_subjects(candidate.subject, candidate.evidence),
         :ok <- admit_standing(Evidence.standing(candidate.evidence)) do
      {:ok, candidate}
    end
  end

  def admit(other), do: {:error, {:refused, :invalid_capsule_candidate, other}}

  defp admit_evidence_subjects(subject, evidence) do
    if Enum.all?(evidence, fn item -> Subject.same?(subject, item.subject) end) do
      :ok
    else
      {:error, {:refused, :foreign_capsule_evidence}}
    end
  end

  defp admit_standing(:partial_alive), do: :ok
  defp admit_standing(:unsupported), do: {:error, {:unsupported, :capsule_unavailable}}
  defp admit_standing(:build_broken), do: {:error, {:refused, :capsule_build_broken}}
  defp admit_standing(:unknown), do: {:error, {:refused, :capsule_unproven}}
  defp admit_standing({:refused, reason}), do: {:error, {:refused, reason}}
end
