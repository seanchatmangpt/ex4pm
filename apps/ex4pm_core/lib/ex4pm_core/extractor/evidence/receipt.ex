defmodule Ex4pmCore.ProcessIR.Extractor.Evidence.Receipt do
  @moduledoc false

  alias Ex4pmCore.ProcessIR.Extractor.Evidence.Digest

  @enforce_keys [:extractor, :source_digest, :output_digest, :body_digest]
  defstruct [:extractor, :source_digest, :output_digest, :body_digest, authority: :construct_only]

  def new(extractor, source_digest, output_digest)
      when is_atom(extractor) and is_binary(source_digest) and is_binary(output_digest) do
    body = %{extractor: extractor, source_digest: source_digest, output_digest: output_digest, authority: :construct_only}

    %__MODULE__{
      extractor: extractor,
      source_digest: source_digest,
      output_digest: output_digest,
      body_digest: Digest.of(body)
    }
  end
end
