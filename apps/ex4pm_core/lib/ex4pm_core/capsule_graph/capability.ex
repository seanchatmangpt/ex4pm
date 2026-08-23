defmodule Ex4pmCore.CapsuleGraph.Capability do
  @moduledoc false

  @enforce_keys [:name, :protocol]
  defstruct [:name, :protocol]

  def new(name, protocol) when is_atom(name) and is_binary(protocol) do
    if protocol != "" and String.contains?(protocol, "/") do
      {:ok, %__MODULE__{name: name, protocol: protocol}}
    else
      {:error, {:refused, :invalid_capability_protocol, {name, protocol}}}
    end
  end

  def new(name, protocol), do: {:error, {:refused, :invalid_capability_protocol, {name, protocol}}}

  def satisfies?(%__MODULE__{} = provided, %__MODULE__{} = required), do: provided == required
end
