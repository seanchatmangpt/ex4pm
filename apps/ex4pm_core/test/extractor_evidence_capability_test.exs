defmodule Ex4pmCore.ExtractorEvidenceCapabilityTest do
  use ExUnit.Case, async: true

  alias Ex4pmCore.ProcessIR.Extractor.Evidence.Capability

  test "known capability admits and unknown capability refuses" do
    assert {:ok, :actions} = Capability.admit(:actions)

    assert {:error, {:refused, :unknown_introspection_capability, :telepathy}} =
             Capability.admit(:telepathy)

    assert :steps in Capability.known()
  end
end
