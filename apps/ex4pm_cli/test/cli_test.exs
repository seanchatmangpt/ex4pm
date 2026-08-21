defmodule Ex4pm.CLITest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  test "doctor exposes the complete engine candidate graph" do
    output = capture_io(fn -> Ex4pm.CLI.main(["doctor"]) end)
    assert output =~ "beam"
    assert output =~ "wasm"
    assert output =~ "nif"
    assert output =~ "remote"
  end
end
