defmodule Ex4pmCore.ProcessIR.Extractor.Evidence.Provenance do
  @moduledoc false

  def new(extractor, source_digest, output_digest, alternatives)
      when is_atom(extractor) and is_binary(source_digest) and is_binary(output_digest) and
             is_list(alternatives) do
    %{
      extractor: extractor,
      source_digest: source_digest,
      output_digest: output_digest,
      alternatives: Enum.sort(alternatives),
      authority: :construct_only
    }
  end
end
