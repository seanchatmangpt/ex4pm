defmodule Ex4pmCore.WS5.XmerlRuntimeContractTest do
  use ExUnit.Case, async: true

  test "canonical core keeps xmerl available for XML semantics" do
    source = File.read!("apps/ex4pm_core/mix.exs")
    assert source =~ ":xmerl"
  end
end
