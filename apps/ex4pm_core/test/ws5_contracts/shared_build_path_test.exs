defmodule Ex4pmCore.WS5.SharedBuildPathTest do
  use ExUnit.Case, async: true

  test "core builds through the umbrella build root" do
    source = File.read!("apps/ex4pm_core/mix.exs")
    assert source =~ ~s(build_path: "../../_build")
  end
end
