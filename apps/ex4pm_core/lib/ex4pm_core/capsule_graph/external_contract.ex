defmodule Ex4pmCore.CapsuleGraph.ExternalContract do
  @moduledoc false

  alias Ex4pmCore.CapsuleGraph.{Capability, Runtime, Subject}

  @enforce_keys [:subject, :runtime, :required_capabilities]
  defstruct [:subject, :runtime, :required_capabilities]

  def new(%Subject{} = subject, %Runtime{} = runtime, required_capabilities)
      when is_list(required_capabilities) do
    if Enum.all?(required_capabilities, &match?(%Capability{}, &1)) do
      {:ok,
       %__MODULE__{
         subject: subject,
         runtime: runtime,
         required_capabilities: required_capabilities
       }}
    else
      {:error, {:refused, :invalid_external_contract}}
    end
  end

  def new(_, _, _), do: {:error, {:refused, :invalid_external_contract}}
end
