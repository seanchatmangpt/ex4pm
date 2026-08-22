defmodule Ex4pmCore.ProcessIR.Extractor.Evidence.Candidate do
  @moduledoc false

  alias Ex4pmCore.ProcessIR.Extractor.Evidence.Registry

  def observe(name) do
    with {:ok, module} <- Registry.fetch(name) do
      standing = if Code.ensure_loaded?(module) and function_exported?(module, :extract, 2), do: :partial_alive, else: :unsupported
      {:ok, %{name: name, module: module, standing: standing}}
    end
  end

  def observe_all do
    Registry.candidates()
    |> Enum.map(fn {name, _module} -> observe(name) end)
  end
end
