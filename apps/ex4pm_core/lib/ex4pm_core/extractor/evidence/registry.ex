defmodule Ex4pmCore.ProcessIR.Extractor.Evidence.Registry do
  @moduledoc false

  @candidates %{
    ash: Ex4pmCore.ProcessIR.Extractor.Ash,
    ash_state_machine: Ex4pmCore.ProcessIR.Extractor.AshStateMachine,
    reactor: Ex4pmCore.ProcessIR.Extractor.Reactor
  }

  def candidates do
    @candidates
    |> Enum.sort_by(fn {name, _module} -> name end)
  end

  def fetch(name) when is_atom(name) do
    case Map.fetch(@candidates, name) do
      {:ok, module} -> {:ok, module}
      :error -> {:error, {:refused, :unknown_extractor, name}}
    end
  end
end
