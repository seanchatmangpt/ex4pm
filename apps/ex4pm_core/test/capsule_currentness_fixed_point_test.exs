defmodule Ex4pmCore.CapsuleCurrentnessFixedPointTest do
  use ExUnit.Case, async: true
  alias Ex4pmCore.CapsuleGraph.Currentness.FixedPoint

  test "monotone closure converges and bounded oscillation refuses" do
    assert {:ok, %{x: 2}} = FixedPoint.close(%{x: 0}, fn %{x: x} = s -> %{s | x: min(x + 1, 2)} end)
    assert {:error, {:refused, :non_convergent_fixed_point, _}} =
             FixedPoint.close(%{x: 0}, fn %{x: x} = s -> %{s | x: 1 - x} end, 3)
  end
end
