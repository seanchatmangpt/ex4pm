defmodule Ex4pmCore.WS5.XmerlRuntimeContractTest do
  use ExUnit.Case, async: true

  test "canonical core keeps xmerl available for XML semantics" do
    source = File.read!("mix.exs")
    assert source =~ ":xmerl"
  end
end
