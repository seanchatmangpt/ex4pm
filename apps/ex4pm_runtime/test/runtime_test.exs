defmodule Ex4pm.RuntimeTest do
  use ExUnit.Case, async: false

  alias Ex4pm.POWL
  alias Ex4pm.Runtime

  test "POWL compiles into concurrent layers and every task crosses BRCE" do
    assert {:ok, model} =
             POWL.new(
               [
                 %{id: "a", label: "A"},
                 %{id: "b", label: "B"},
                 %{id: "c", label: "C"},
                 %{id: "d", label: "D"}
               ],
               [{"a", "b"}, {"a", "c"}, {"b", "d"}, {"c", "d"}]
             )

    assert {:ok, plan} = Runtime.compile(model)

    assert Enum.map(plan.layers, &Enum.map(&1, fn task -> task.id end)) == [
             ["a"],
             ["b", "c"],
             ["d"]
           ]

    authority = %{id: "test", capabilities: [:do]}
    assert {:ok, execution} = Runtime.execute(plan, authority)
    assert execution.standing == :alive
    assert length(execution.receipt_hashes) == 4
  end

  test "cyclic POWL is refused before runtime construction" do
    assert {:error, %Ex4pm.Refusal{code: :cyclic_powl}} =
             POWL.new([%{id: "a"}, %{id: "b"}], [{"a", "b"}, {"b", "a"}])
  end
end
