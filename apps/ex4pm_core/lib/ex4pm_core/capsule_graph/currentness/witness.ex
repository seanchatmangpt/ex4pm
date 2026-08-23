defmodule Ex4pmCore.CapsuleGraph.Currentness.Witness do
  @moduledoc false
  @kinds [:exact, :semantic_equivalent, :backward_compatible]
  @results [:pass, :fail, :pending, :unknown, :unsupported]
  @enforce_keys [:before_digest, :after_digest, :kind, :result]
  defstruct [:before_digest, :after_digest, :kind, :result]

  def new(before_digest, after_digest, kind, result)
      when kind in @kinds and result in @results and is_binary(before_digest) and is_binary(after_digest) do
    if kind == :exact and before_digest != after_digest,
      do: {:error, {:refused, :false_exact_witness}},
      else: {:ok, %__MODULE__{before_digest: before_digest, after_digest: after_digest, kind: kind, result: result}}
  end

  def new(_, _, _, _), do: {:error, {:refused, :invalid_witness}}
end
