defmodule Ex4pm.CLITest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  test "doctor exposes the complete engine candidate graph and contract identity" do
    output = capture_io(fn -> Ex4pm.CLI.main(["doctor"]) end)
    assert output =~ "beam"
    assert output =~ "wasm"
    assert output =~ "nif"
    assert output =~ "remote"
    assert output =~ "contracts"
    assert output =~ "sha256:"
  end

  test "contracts command emits the canonical artifact graph" do
    output = capture_io(fn -> Ex4pm.CLI.main(["contracts"]) end)
    assert output =~ "contract_hash"
    assert output =~ "ontology"
    assert output =~ "shacl"
    assert output =~ "wit"
  end
end
