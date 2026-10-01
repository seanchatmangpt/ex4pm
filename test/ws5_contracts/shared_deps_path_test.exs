defmodule Ex4pmCore.WS5.SharedDepsPathTest do
  use ExUnit.Case, async: true

  test "core resolves dependencies from umbrella root" do
    source = File.read!("apps/ex4pm_core/mix.exs")
    assert source =~ ~s(deps_path: "../../deps")
  end
end
