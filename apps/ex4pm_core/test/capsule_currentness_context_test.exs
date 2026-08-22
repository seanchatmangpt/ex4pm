defmodule Ex4pmCore.CapsuleCurrentnessContextTest do
  use ExUnit.Case, async: true
  alias Ex4pmCore.CapsuleGraph.Currentness.{Context, Subject}

  test "context digest is deterministic and generation bounded" do
    {:ok, subject} = Subject.new("owner/repo", String.duplicate("b", 40))
    assert {:ok, ctx1, digest1} = Context.new(subject, 3, "cut-a", "policy", "frontier")
    assert {:ok, ctx2, digest2} = Context.new(subject, 3, "cut-a", "policy", "frontier")
    assert ctx1 == ctx2
    assert digest1 == digest2
    assert {:error, {:refused, :invalid_context}} = Context.new(subject, -1, "cut", "p", "f")
  end
end
