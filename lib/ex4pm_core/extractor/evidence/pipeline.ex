defmodule Ex4pmCore.ProcessIR.Extractor.Evidence.Pipeline do
  @moduledoc false

  alias Ex4pmCore.ProcessIR

  alias Ex4pmCore.ProcessIR.Extractor.Evidence.{
    Candidate,
    Digest,
    Output,
    Receipt,
    Registry,
    Selector,
    Source
  }

  def extract(extractor_name, source_identity, subject, opts \\ []) do
    with {:ok, source} <- Source.new(extractor_name, source_identity),
         {:ok, candidate} <- Candidate.observe(extractor_name),
         {:ok, selected, alternatives} <- Selector.select([candidate]),
         {:ok, module} <- Registry.fetch(selected.name),
         %ProcessIR{} = raw <- module.extract(subject, opts),
         {:ok, admitted} <- Output.admit(raw) do
      output_digest = ProcessIR.digest(admitted)
      receipt = Receipt.new(selected.name, source.digest, output_digest)

      {:ok,
       %{
         process_ir: admitted,
         receipt: receipt,
         alternatives: alternatives,
         evidence_digest: Digest.of({source.digest, output_digest, alternatives}),
         standing: :partial_alive,
         authority: :construct_only
       }}
    else
      {:error, _} = error -> error
      other -> {:error, {:refused, :invalid_extractor_result, other}}
    end
  end
end
