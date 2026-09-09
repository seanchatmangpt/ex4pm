defmodule Ex4pmCore.CapsuleIndependenceFrontierTest do
  use ExUnit.Case, async: true
  alias Ex4pmCore.CapsuleGraph.Independence.{Frontier, Witness}

  test "frontier separates attempts and refuses future evidence" do
    now = DateTime.utc_now()
    current = String.duplicate("a", 64)
    historical = String.duplicate("b", 64)
    source = String.duplicate("c", 64)
    {:ok, w1} = Witness.new(source, current, :pass, :repository, now, "current")
    {:ok, w2} = Witness.new(source, historical, :pass, :repository, now, "historical")

    assert {:ok, %{current: [^w1], historical: [^w2]}} = Frontier.build([w1, w2], current, now)

    {:ok, future} =
      Witness.new(source, current, :pass, :repository, DateTime.add(now, 1, :second), "future")

    assert {:error, {:refused, :future_evidence}} = Frontier.build([future], current, now)
  end
end
