defmodule Ex4pmCore.ProcessIR.Extractor.Evidence.Source do
  @moduledoc false

  @enforce_keys [:kind, :identity, :digest]
  defstruct [:kind, :identity, :digest]

  def new(kind, identity) when is_atom(kind) do
    digest =
      identity
      |> :erlang.term_to_binary([:deterministic])
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    {:ok, %__MODULE__{kind: kind, identity: identity, digest: digest}}
  rescue
    _ -> {:error, {:refused, :unencodable_source_identity}}
  end

  def new(_, _), do: {:error, {:refused, :invalid_source_kind}}
end
