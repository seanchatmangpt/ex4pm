defmodule Ex4pmCore.ExtractorEvidenceIntrospectorTest do
  use ExUnit.Case, async: true

  alias Ex4pmCore.ProcessIR.Extractor.Evidence.Introspector

  defmodule Probe do
    def explode, do: raise("boom")
    def value, do: [:ok]
  end

  test "missing capability is unsupported rather than empty success" do
    assert {:error, {:unsupported, :capability_unavailable, {Probe, :missing, 0}}} = Introspector.call(Probe, :missing, [])
  end

  test "raised reflection is a typed refusal" do
    assert {:error, {:refused, :introspection_raised, RuntimeError}} = Introspector.call(Probe, :explode, [])
    assert {:ok, [:ok]} = Introspector.call(Probe, :value, [])
  end
end
