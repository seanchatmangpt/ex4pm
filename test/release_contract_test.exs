defmodule Ex4pm.Qualification.ReleaseContractTest do
  use ExUnit.Case, async: true

  alias Ex4pm.Qualification.ReleaseContract

  test "missing external authority cannot be promoted to ALIVE" do
    evidence =
      ReleaseContract.obligations()
      |> Map.new(&{&1.id, :alive})
      |> Map.put(:global_topology, :unknown)

    result = ReleaseContract.evaluate(evidence)

    assert result.version == "26.8.23"
    assert result.standing == :partial_alive
    assert result.missing == [:global_topology]
    assert result.external_authority == [:global_topology]
  end

  test "every admitted obligation must be ALIVE for release ALIVE" do
    evidence = Map.new(ReleaseContract.obligations(), &{&1.id, "ALIVE"})
    result = ReleaseContract.evaluate(evidence)

    assert result.standing == :alive
    assert result.missing == []
    assert result.blocked == []
  end

  test "explicit falsifiers dominate missing evidence" do
    evidence = %{
      powl_correspondence: :alive,
      compiler_refinement: :build_broken,
      global_topology: :unknown
    }

    result = ReleaseContract.evaluate(evidence)

    assert result.standing == :blocked
    assert :compiler_refinement in result.blocked
    assert :global_topology in result.missing
  end
end
