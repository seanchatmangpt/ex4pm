defmodule Ex4pmCore.CapsuleGraph.PipelineTest do
  use ExUnit.Case, async: true

  alias Ex4pmCore.CapsuleGraph.{
    Capability,
    Candidate,
    Evidence,
    Pipeline,
    Replay,
    Runtime,
    Subject,
    Transport
  }

  test "selects exact planner capsule, preserves alternatives, receipts construct, never actuates" do
    {:ok, capability} = Capability.new(:plan, "ex4pm-plan/v1")

    {:ok, subject} =
      Subject.new("seanchatmangpt/ex4pm-plan", "e5da34c8b42089f1ebb1fd2306d95f0c4986f8c3")

    {:ok, runtime} = Runtime.new(:oci, "ex4pm-plan/v1", "linux-x86_64")
    {:ok, transport} = Transport.new(:oci, "sha256:observed-image")
    {:ok, e2e} = Evidence.new(subject, :e2e, :pass, "worker-cost-2")
    {:ok, replay} = Evidence.new(subject, :replay, :pass, "worker-replay")

    {:ok, candidate} =
      Candidate.new("ex4pm-plan", subject, runtime, transport, [capability], [e2e, replay])

    assert {:ok, result} =
             Pipeline.construct([candidate], [capability], %{graph: :admitted}, %{cost: 2})

    assert result.selected.id == "ex4pm-plan"
    assert result.alternatives == ["ex4pm-plan"]
    refute result.actuation_performed
    assert result.receipt.authority == :construct_only
    assert {:ok, :match} = Replay.verify(result.receipt)
  end
end
