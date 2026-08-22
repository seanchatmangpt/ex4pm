defmodule Ex4pmCore.ProcessIR.Extractor.Evidence.Output do
  @moduledoc false

  alias Ex4pmCore.ProcessIR

  def admit(%ProcessIR{} = ir) do
    ir
    |> ProcessIR.to_canonical_map()
    |> ProcessIR.new()
  end

  def admit(other), do: {:error, {:refused, :extractor_returned_non_process_ir, other}}
end
