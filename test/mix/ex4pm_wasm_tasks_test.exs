defmodule Mix.Tasks.Ex4pmWasmTasksTest do
  @moduledoc "Chicago tests of the ex4pm.wasm.* / ex4pm.ferroplan.* / ex4pm.health mix tasks."
  use ExUnit.Case, async: false

  @fixtures Path.expand("../support/fixtures/ferroplan", __DIR__)
  @artifact Path.expand("../../priv/wasm4pm/wasm4pm_ex4pm_bindings.wasm", __DIR__)

  setup do
    previous = Mix.shell()
    Mix.shell(Mix.Shell.Process)
    on_exit(fn -> Mix.shell(previous) end)
    :ok
  end

  defp infos(acc \\ []) do
    receive do
      {:mix_shell, :info, [line]} -> infos([line | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  test "ex4pm.wasm.verify admits the artifact and prints all 33 algorithms" do
    assert :ok = Mix.Tasks.Ex4pm.Wasm.Verify.run([])
    out = Enum.join(infos(), "\n")
    assert out =~ "admitted true"
    assert out =~ "trend_classify"
    assert out =~ "ok (33 algorithms)"
    refute out =~ "REFUSED"
  end

  test "ex4pm.wasm.verify refuses an absent artifact with REFUSED_NO_ARTIFACT" do
    assert_raise Mix.Error, ~r/^REFUSED_NO_ARTIFACT/, fn ->
      Mix.Tasks.Ex4pm.Wasm.Verify.run(["--artifact", "/nonexistent/x.wasm"])
    end
  end

  test "ex4pm.wasm.verify refuses a tampered artifact with REFUSED_ADMISSION" do
    path = Path.join(System.tmp_dir!(), "tampered-#{System.unique_integer([:positive])}.wasm")
    File.write!(path, File.read!(@artifact) <> <<0>>)
    on_exit(fn -> File.rm(path) end)

    assert_raise Mix.Error, ~r/^REFUSED_ADMISSION: wasm_digest_mismatch/, fn ->
      Mix.Tasks.Ex4pm.Wasm.Verify.run(["--artifact", path])
    end
  end

  test "ex4pm.wasm.doctor and ex4pm.health print JSON and exit clean when ALIVE" do
    assert :ok = Mix.Tasks.Ex4pm.Wasm.Doctor.run([])
    doctor = Jason.decode!(Enum.join(infos(), "\n"))
    assert doctor["wasm4pm"]["standing"] == "alive"
    assert length(doctor["engines"]) == 33

    assert :ok = Mix.Tasks.Ex4pm.Health.run([])
    assert Jason.decode!(Enum.join(infos(), "\n"))["standing"] == "alive"
  end

  test "ex4pm.ferroplan.verify, version and readiness execute the real wasm" do
    assert :ok = Mix.Tasks.Ex4pm.Ferroplan.Verify.run([])
    out = Enum.join(infos(), "\n")
    assert out =~ "ferroplan version"
    assert out =~ "ferroplan readiness"

    assert Mix.Tasks.Ex4pm.Ferroplan.Version.run([]) == :ok
    assert Jason.decode!(Enum.join(infos(), "\n"))["receipt"] =~ "sha256:"

    assert Mix.Tasks.Ex4pm.Ferroplan.Readiness.run([]) == :ok
    assert Jason.decode!(Enum.join(infos(), "\n"))["receipt"] =~ "sha256:"
  end

  test "ex4pm.ferroplan.plan solves the fixture; bad arguments are typed refusals" do
    domain = Path.join(@fixtures, "logistics_domain.pddl")
    problem = Path.join(@fixtures, "logistics_p1.pddl")

    assert Mix.Tasks.Ex4pm.Ferroplan.Plan.run([domain, problem]) == :ok
    assert Jason.decode!(Enum.join(infos(), "\n"))["solution"]["solved"] == true

    assert_raise Mix.Error, ~r/^REFUSED_USAGE/, fn -> Mix.Tasks.Ex4pm.Ferroplan.Plan.run([]) end

    assert_raise Mix.Error, ~r/^REFUSED_NO_INPUT/, fn ->
      Mix.Tasks.Ex4pm.Ferroplan.Plan.run(["/nonexistent.pddl", problem])
    end
  end

  test "Verify.refused/1 renders the refusal code" do
    assert Mix.Tasks.Ex4pm.Ferroplan.Verify.refused(
             Ex4pm.Refusal.new(:ferroplan_artifact_missing, "gone")
           ) == "REFUSED_FERROPLAN_ARTIFACT_MISSING: gone"
  end
end
