defmodule Ex4pmCore.WS5.VerifyTestStageTest do
  use ExUnit.Case, async: true

  test "verify keeps the application test stage" do
    mix = File.read!(Path.expand("../../mix.exs", __DIR__))
    # verify's test step now includes :integration/:stress explicitly (see
    # test/test_helper.exs -- those tags are excluded from plain `mix test`
    # for a fast default inner loop, so the real full gate has to
    # re-include them here or its own coverage would silently shrink).
    assert mix =~ ~s("test --include integration --include stress",\n        "ex4pm.powl.court")
  end
end
