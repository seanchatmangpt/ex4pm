defmodule Ex4pm.CLITest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureIO

  test "doctor preserves complete engine graph through the Reactor information plane" do
    output = capture_io(fn -> Ex4pm.CLI.main(["doctor"]) end)
    assert output =~ "\"protocol\": \"ex4pm.information/1\""
    assert output =~ "\"status\": \"ok\""
    assert output =~ "beam"
    assert output =~ "wasm"
    assert output =~ "nif"
    assert output =~ "remote"
    assert output =~ "contracts"
    assert output =~ "information"
  end

  test "contracts command emits the canonical artifact graph through Reactor" do
    output = capture_io(fn -> Ex4pm.CLI.main(["contracts"]) end)
    assert output =~ "\"status\": \"ok\""
    assert output =~ "contract_hash"
    assert output =~ "ontology"
    assert output =~ "shacl"
    assert output =~ "wit"
    assert output =~ "\"information\""
  end

  test "manifest exposes DfCM interop candidates without creating an execution request" do
    output = capture_io(fn -> Ex4pm.CLI.main(["manifest"]) end)
    assert output =~ "\"release\": \"26.8.22\""
    assert output =~ "jsonl_stdio"
    assert output =~ "wasm4pm"
    assert output =~ "pm4py"
    assert output =~ "clap_noun_verb_any"
    assert output =~ "runtime.operate"
    assert output =~ "ash.mutate"
  end

  test "run uses the explicit capability registry instead of module dispatch" do
    output =
      capture_io(fn ->
        Ex4pm.CLI.main([
          "run",
          "engine.candidates",
          ~s({"input":{"operation":"discover"}})
        ])
      end)

    assert output =~ "\"status\": \"ok\""
    assert output =~ "\"capability\": \"engine.candidates\""
    assert output =~ "\"information\""
  end

  test "stdio emits exactly one JSON response per non-empty request line" do
    input =
      [
        Jason.encode!(%{
          "capability" => "engine.candidates",
          "input" => %{"operation" => "discover"}
        }),
        "",
        Jason.encode!(%{"capability" => "system.contracts"})
      ]
      |> Enum.join("\n")
      |> Kernel.<>("\n")

    output = capture_io(input, fn -> Ex4pm.CLI.main(["stdio"]) end)

    lines =
      output
      |> String.split("\n", trim: true)
      |> Enum.map(&Jason.decode!/1)

    assert length(lines) == 2
    assert Enum.all?(lines, &(&1["protocol"] == "ex4pm.information/1"))
    assert Enum.all?(lines, & &1["receipts"]["information"])
  end
end
