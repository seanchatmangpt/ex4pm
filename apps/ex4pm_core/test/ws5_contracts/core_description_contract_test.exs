defmodule Ex4pmCore.WS5.CoreDescriptionContractTest do
  use ExUnit.Case, async: true

  test "package description keeps ex4pm_core as canonical semantic core" do
    source = File.read!("apps/ex4pm_core/mix.exs")
    assert source =~ ~s(description: "Canonical semantic core for ex4pm process intelligence")
  end
end
