defmodule Ex4pmCore.WS5.TestSupportCompilePathTest do
  use ExUnit.Case, async: true

  test "test environment compiles core support modules" do
    source = File.read!("mix.exs")
    assert source =~ ~s|"test/support"|
  end
end
