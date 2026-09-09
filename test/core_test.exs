defmodule Ex4pm.CoreTest do
  use ExUnit.Case, async: true

  alias Ex4pm.{OCEL, POWL}
  alias Ex4pm.Core.Hash

  test "canonical hashes are map-order independent" do
    assert Hash.digest(%{a: 1, b: 2}) == Hash.digest(%{b: 2, a: 1})
  end

  test "OCEL refuses references to objects outside the admitted subject" do
    raw = %{
      "objects" => %{"o1" => %{"type" => "Order"}},
      "events" => %{
        "e1" => %{
          "activity" => "ship",
          "timestamp" => "2026-01-01T00:00:00Z",
          "objects" => ["missing"]
        }
      }
    }

    assert {:error, %Ex4pm.Refusal{code: :unknown_object_reference}} = OCEL.normalize(raw)
  end

  test "POWL preserves independent tasks in the same deterministic layer" do
    assert {:ok, model} =
             POWL.new(
               [%{id: "a"}, %{id: "b"}, %{id: "c"}],
               [{"a", "c"}, {"b", "c"}]
             )

    assert POWL.layers(model) == [["a", "b"], ["c"]]
  end
end
