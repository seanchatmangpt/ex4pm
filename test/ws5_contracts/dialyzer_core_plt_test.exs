defmodule Ex4pmCore.WS5.DialyzerCorePltTest do
  use ExUnit.Case, async: true
  @manifest File.read!(Path.expand("../../../../mix.exs", __DIR__))

  test "Dialyzer core PLT path remains deterministic" do
    assert @manifest =~ ~s(plt_core_path: "priv/plts/core.plt")
  end
end
