defmodule Ex4pmCore.CapsuleGraph.EvidenceTest do
  use ExUnit.Case, async: true

  alias Ex4pmCore.CapsuleGraph.{Evidence, Subject}

  test "green observations remain partial and failures remain build broken" do
    {:ok, subject} = Subject.new("seanchatmangpt/chatgpt-cloud-elixir", String.duplicate("b", 40))
    {:ok, compile} = Evidence.new(subject, :compile, :pass, "run:1")
    {:ok, replay} = Evidence.new(subject, :replay, :pass, "receipt:1")
    assert Evidence.standing([compile, replay]) == :partial_alive

    {:ok, failed} = Evidence.new(subject, :integration, :fail, "run:2")
    assert Evidence.standing([compile, failed]) == :build_broken
  end
end
