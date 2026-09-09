defmodule Ex4pmCore.CapsuleCurrentnessSubjectTest do
  use ExUnit.Case, async: true
  alias Ex4pmCore.CapsuleGraph.Currentness.Subject

  test "admits exact repository sha and refuses moving identities" do
    sha = String.duplicate("a", 40)
    assert {:ok, %Subject{repository: "owner/repo", sha: ^sha}} = Subject.new("owner/repo", sha)
    assert {:error, {:refused, :inexact_subject}} = Subject.new("owner/repo", "main")
    assert {:error, {:refused, :inexact_subject}} = Subject.new("owner /repo", sha)
  end
end
