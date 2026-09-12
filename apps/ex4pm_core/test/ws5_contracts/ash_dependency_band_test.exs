defmodule Ex4pmCore.WS5.AshDependencyBandTest do
  use ExUnit.Case, async: true

  test "canonical core remains on Ash 3.31 compatibility band" do
    source = File.read!("apps/ex4pm_core/mix.exs")
    assert source =~ ~s({:ash, "~> 3.31"})
  end
end
