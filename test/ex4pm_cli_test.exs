defmodule Ex4pm.CliWasmTest do
  @moduledoc "Chicago tests of the wasm4pm / ferroplan CLI subcommands (real bundled artifacts)."
  use ExUnit.Case, async: false
  import ExUnit.CaptureIO

  @fixtures Path.expand("support/fixtures/ferroplan", __DIR__)

  test "health prints JSON with ALIVE standing for both engines" do
    out = capture_io(fn -> Ex4pm.CLI.main(["health"]) end)
    decoded = Jason.decode!(out)
    assert decoded["standing"] == "alive"
    assert decoded["wasm4pm"]["admitted"] == true
    assert decoded["wasm4pm"]["probe"] == "ok"
    assert decoded["ferroplan"]["admitted"] == true
    assert is_binary(decoded["ferroplan"]["version"])
  end

  test "wasm verify admits the artifact and executes all 33 algorithms" do
    out = capture_io(fn -> Ex4pm.CLI.main(["wasm", "verify"]) end)
    decoded = Jason.decode!(out)
    assert decoded["admitted"] == true
    assert decoded["refusal"] == nil
    assert length(decoded["rows"]) == 33
    assert Enum.all?(decoded["rows"], &(&1["status"] == "ok"))
  end

  test "ferroplan version and readiness run the real wasm" do
    version = Jason.decode!(capture_io(fn -> Ex4pm.CLI.main(["ferroplan", "version"]) end))
    assert version["standing"] == "alive"
    assert is_binary(version["receipt"])

    readiness = Jason.decode!(capture_io(fn -> Ex4pm.CLI.main(["ferroplan", "readiness"]) end))
    assert readiness["receipt"] =~ "sha256:"
  end

  test "ferroplan plan solves the logistics fixture" do
    domain = Path.join(@fixtures, "logistics_domain.pddl")
    problem = Path.join(@fixtures, "logistics_p1.pddl")

    out = capture_io(fn -> Ex4pm.CLI.main(["ferroplan", "plan", domain, problem]) end)
    assert Jason.decode!(out)["model"]["solved"] == true
  end

  test "forecast accepts a JSON array and an options object" do
    out = capture_io(fn -> Ex4pm.CLI.main(["forecast", "[1, 2, 3, 4, 5]"]) end)
    assert Jason.decode!(out)["receipt"] =~ "sha256:"

    out =
      capture_io(fn ->
        Ex4pm.CLI.main(["forecast", ~s({"series": [1,2,3,4,5], "method": "holt", "alpha": 0.5})])
      end)

    assert Jason.decode!(out)["receipt"] =~ "sha256:"
  end

  test "doctor lists ferroplan alongside the discover candidates" do
    out = capture_io(fn -> Ex4pm.CLI.main(["doctor"]) end)
    decoded = Jason.decode!(out)
    assert [%{"engine" => "ferroplan", "standing" => "partial_alive"}] = decoded["ferroplan"]
    assert Enum.any?(decoded["candidates"], &(&1["engine"] == "beam"))
  end

  test "help documents the new subcommands" do
    out = capture_io(fn -> Ex4pm.CLI.main(["help"]) end)

    for needle <- ["health", "wasm verify", "ferroplan version", "ferroplan plan", "forecast"] do
      assert out =~ needle
    end
  end

  test "to_json keeps nil/booleans and projects refusals" do
    json =
      Ex4pm.CLI.to_json(%{a: nil, b: true, r: Ex4pm.Refusal.new(:x, "m"), t: {:error, :y}})

    assert json == %{
             "a" => nil,
             "b" => true,
             "r" => %{"code" => "x", "message" => "m", "subject" => nil, "details" => %{}},
             "t" => ["error", "y"]
           }
  end
end
