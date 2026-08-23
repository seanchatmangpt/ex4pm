defmodule Ex4pmCore.CapsuleGraph.Compatibility do
  @moduledoc false

  alias Ex4pmCore.CapsuleGraph.Capability

  def verify(provided, required) when is_list(provided) and is_list(required) do
    missing =
      required
      |> Enum.reject(fn requirement -> Enum.any?(provided, &Capability.satisfies?(&1, requirement)) end)
      |> Enum.sort_by(&{&1.name, &1.protocol})

    case missing do
      [] -> {:ok, :compatible}
      _ -> {:error, {:unsupported, :missing_capabilities, missing}}
    end
  end
end
