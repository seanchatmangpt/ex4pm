defmodule Ex4pmCore.ExtractorEvidencePipelineTest do
  use ExUnit.Case, async: true

  alias Ex4pmCore.ProcessIR.Extractor.Evidence.{Pipeline, Replay}

  test "reactor candidate constructs canonical evidence without DO authority" do
    assert {:ok, result} = Pipeline.extract(:reactor, %{module: Enum}, Enum)
    assert result.process_ir.subject != nil
    assert result.standing == :partial_alive
    assert result.authority == :construct_only
    assert {:ok, :match} = Replay.verify(result.receipt)
    assert result.alternatives == [:reactor]
  end
end
