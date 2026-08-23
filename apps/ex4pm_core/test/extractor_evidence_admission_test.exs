defmodule Ex4pmCore.ExtractorEvidenceAdmissionTest do
  use ExUnit.Case, async: true

  alias Ex4pmCore.ProcessIR.Extractor.Evidence.Admission

  test "partial candidate admits and unsupported candidate does not" do
    assert {:ok, %{name: :ash}} = Admission.admit(%{name: :ash, standing: :partial_alive})

    assert {:error, {:unsupported, :extractor_unavailable, :ash}} =
             Admission.admit(%{name: :ash, standing: :unsupported})
  end
end
