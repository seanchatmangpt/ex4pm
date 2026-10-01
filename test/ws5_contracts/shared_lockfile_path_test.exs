defmodule Ex4pmCore.WS5.SharedLockfilePathTest do
  use ExUnit.Case, async: true

  test "core shares the umbrella dependency lock" do
    source = File.read!("apps/ex4pm_core/mix.exs")
    assert source =~ ~s(lockfile: "../../mix.lock")
  end
end
