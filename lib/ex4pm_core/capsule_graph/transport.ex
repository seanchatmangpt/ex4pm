defmodule Ex4pmCore.CapsuleGraph.Transport do
  @moduledoc false

  @modes [:beam, :wasm, :nif, :oci, :remote]
  @enforce_keys [:mode, :identity]
  defstruct [:mode, :identity]

  def new(mode, identity) when mode in @modes and is_binary(identity) and identity != "" do
    {:ok, %__MODULE__{mode: mode, identity: identity}}
  end

  def new(mode, identity), do: {:error, {:refused, :invalid_transport, {mode, identity}}}

  def modes, do: @modes
end
