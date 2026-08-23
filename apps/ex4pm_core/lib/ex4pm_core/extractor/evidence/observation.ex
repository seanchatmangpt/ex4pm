defmodule Ex4pmCore.ProcessIR.Extractor.Evidence.Observation do
  @moduledoc false

  @enforce_keys [:extractor, :capability, :source_digest, :standing]
  defstruct [:extractor, :capability, :source_digest, :standing, metadata: %{}]

  @standings [:unknown, :partial_alive, :alive, :blocked, :build_broken, :unsupported]

  def new(extractor, capability, source_digest, standing, metadata \\ %{})

  def new(extractor, capability, source_digest, standing, metadata)
      when is_atom(extractor) and is_atom(capability) and is_binary(source_digest) and is_map(metadata) do
    if standing in @standings do
      {:ok,
       %__MODULE__{
         extractor: extractor,
         capability: capability,
         source_digest: source_digest,
         standing: standing,
         metadata: metadata
       }}
    else
      {:error, {:refused, :invalid_standing, standing}}
    end
  end

  def new(_, _, _, _, _), do: {:error, {:refused, :invalid_observation}}
end
