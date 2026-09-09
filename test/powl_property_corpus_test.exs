defmodule Ex4pm.Qualification.Powl.PropertyCorpusTest do
  use ExUnit.Case, async: false

  alias Ex4pm.Qualification.Powl.PropertyCorpus

  @tag timeout: 120_000
  test "2048 generated models agree across independent semantics with Reactor samples" do
    assert {:ok, evidence} = PropertyCorpus.run(2_048)
    assert evidence.cases == 2_048
    assert evidence.traces > 2_048
    assert evidence.reactor_samples == 64
  end

  test "invalid identity and graph cases are refused before construction" do
    assert {:ok, %{invalid_cases: 4}} = PropertyCorpus.invalid_identity_court()
  end
end
