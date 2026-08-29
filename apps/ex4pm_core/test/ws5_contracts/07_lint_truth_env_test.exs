defmodule Ex4pmCore.WS5.LintTruthEnvTest do
  use ExUnit.Case, async: true

  test "truth lint remains bound to MIX_ENV=test" do
    mix = File.read!(Path.expand("../../../../mix.exs", __DIR__))
    assert mix =~ ~s("ex4pm.lint.truth": :test)
  end
end
