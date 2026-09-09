defmodule Ex4pmCore.ExtractorEvidenceRegistryTest do
  use ExUnit.Case, async: true

  alias Ex4pmCore.ProcessIR.Extractor.Evidence.Registry

  test "all live extractor families remain visible and unknown names refuse" do
    assert Enum.map(Registry.candidates(), &elem(&1, 0)) == [:ash, :ash_state_machine, :reactor]
    assert {:ok, Ex4pmCore.ProcessIR.Extractor.Reactor} = Registry.fetch(:reactor)
    assert {:error, {:refused, :unknown_extractor, :hidden}} = Registry.fetch(:hidden)
  end
end
