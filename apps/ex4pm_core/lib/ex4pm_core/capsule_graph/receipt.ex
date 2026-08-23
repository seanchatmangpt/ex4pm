defmodule Ex4pmCore.CapsuleGraph.Receipt do
  @moduledoc false

  alias Ex4pmCore.CapsuleGraph.{Candidate, Digest}

  @schema "ex4pm.capsule-graph/v1"
  @enforce_keys [
    :schema,
    :candidate_id,
    :subject_sha,
    :input_digest,
    :output_digest,
    :authority,
    :digest
  ]
  defstruct [
    :schema,
    :candidate_id,
    :subject_sha,
    :input_digest,
    :output_digest,
    :authority,
    :digest
  ]

  def new(%Candidate{} = candidate, input, output) do
    body = %{
      schema: @schema,
      candidate_id: candidate.id,
      subject_sha: candidate.subject.sha,
      input_digest: Digest.sha256(input),
      output_digest: Digest.sha256(output),
      authority: :construct_only
    }

    struct!(__MODULE__, Map.put(body, :digest, Digest.sha256(body)))
  end

  def body(%__MODULE__{} = receipt), do: Map.from_struct(receipt) |> Map.delete(:digest)
end
