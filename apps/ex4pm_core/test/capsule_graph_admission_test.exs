defmodule Ex4pmCore.CapsuleGraph.AdmissionTest do
  use ExUnit.Case, async: true

  alias Ex4pmCore.CapsuleGraph.{Admission, Candidate, Evidence, Runtime, Subject, Transport}

  test "candidate evidence must bind the candidate exact subject" do
    {:ok, subject} = Subject.new("seanchatmangpt/ex4pm-plan", String.duplicate("c", 40))
    {:ok, foreign} = Subject.new("seanchatmangpt/ex4pm-plan", String.duplicate("d", 40))
    {:ok, runtime} = Runtime.new(:oci, "v1", "linux-x86_64")
    {:ok, transport} = Transport.new(:oci, "sha256:image")
    {:ok, evidence} = Evidence.new(foreign, :e2e, :pass, "run:foreign")
    {:ok, candidate} = Candidate.new("planner", subject, runtime, transport, [], [evidence])

    assert {:error, {:refused, :foreign_capsule_evidence}} = Admission.admit(candidate)
  end
end
