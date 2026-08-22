defmodule Ex4pmCore.CapsuleCurrentnessFrontierTest do
  use ExUnit.Case, async: true
  alias Ex4pmCore.CapsuleGraph.Currentness.Frontier

  test "one maximum ordinal is current and ties refuse" do
    a = %{id: "a", ordinal: 1}
    b = %{id: "b", ordinal: 2}
    c = %{id: "c", ordinal: 2}
    assert {:ok, %{current: ^b, historical: [^a]}} = Frontier.build([a, b])
    assert {:error, {:refused, :divergent_attempt_frontier}} = Frontier.build([a, b, c])
  end
end
