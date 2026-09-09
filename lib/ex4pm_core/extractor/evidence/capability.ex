defmodule Ex4pmCore.ProcessIR.Extractor.Evidence.Capability do
  @moduledoc false

  @known MapSet.new([
           :actions,
           :attributes,
           :relationships,
           :policies,
           :states,
           :transitions,
           :initial_states,
           :steps
         ])

  def known, do: @known |> MapSet.to_list() |> Enum.sort()

  def admit(capability) when is_atom(capability) do
    if MapSet.member?(@known, capability) do
      {:ok, capability}
    else
      {:error, {:refused, :unknown_introspection_capability, capability}}
    end
  end

  def admit(capability), do: {:error, {:refused, :invalid_introspection_capability, capability}}
end
