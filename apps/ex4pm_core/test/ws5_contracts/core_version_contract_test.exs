defmodule Ex4pmCore.WS5.CoreVersionContractTest do
  use ExUnit.Case, async: true

  test "canonical core remains on 26.8.22 package line" do
    source = File.read!("apps/ex4pm_core/mix.exs")
    assert source =~ ~s(@version "26.8.22")
  end
end
