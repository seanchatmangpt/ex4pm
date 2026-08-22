defmodule Ex4pmCore.ExtractorEvidenceOutputTest do
  use ExUnit.Case, async: true

  alias Ex4pmCore.ProcessIR
  alias Ex4pmCore.ProcessIR.Extractor.Evidence.Output

  test "canonical ProcessIR is rebuilt with subject identity" do
    assert {:ok, original} = ProcessIR.new(%{id: "p", activities: [%{id: "a"}]})
    assert {:ok, admitted} = Output.admit(original)
    assert admitted.subject != nil
    assert ProcessIR.digest(admitted) == ProcessIR.digest(original)
  end

  test "non ProcessIR output refuses" do
    assert {:error, {:refused, :extractor_returned_non_process_ir, %{}}} = Output.admit(%{})
  end
end
