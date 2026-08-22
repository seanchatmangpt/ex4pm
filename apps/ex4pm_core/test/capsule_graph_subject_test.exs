defmodule Ex4pmCore.CapsuleGraph.SubjectTest do
  use ExUnit.Case, async: true

  alias Ex4pmCore.CapsuleGraph.Subject

  test "admits exact repository SHA and refuses refs or malformed repositories" do
    sha = String.duplicate("a", 40)
    assert {:ok, subject} = Subject.new("seanchatmangpt/ex4pm-plan", sha)
    assert subject.sha == sha

    assert {:error, {:refused, :invalid_exact_subject, _}} =
             Subject.new("seanchatmangpt/ex4pm-plan", "main")

    assert {:error, {:refused, :invalid_exact_subject, _}} = Subject.new("ex4pm-plan", sha)
  end
end
