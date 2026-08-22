defmodule Ex4pmCore.CapsuleGraph.Runtime do
  @moduledoc false

  @kinds [:beam, :wasm, :native, :oci, :remote]
  @enforce_keys [:kind, :version, :architecture]
  defstruct [:kind, :version, :architecture]

  def new(kind, version, architecture)
      when kind in @kinds and is_binary(version) and is_binary(architecture) do
    if version != "" and architecture != "" do
      {:ok, %__MODULE__{kind: kind, version: version, architecture: architecture}}
    else
      {:error, {:refused, :invalid_runtime_identity}}
    end
  end

  def new(_, _, _), do: {:error, {:refused, :invalid_runtime_identity}}

  def kinds, do: @kinds
end
