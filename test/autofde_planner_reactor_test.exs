defmodule Ex4pmEngine.AutoFdePlannerReactorTest do
  use ExUnit.Case, async: false

  alias Ex4pmEngine.Reactors.AutoFdePlannerReactor
  alias Ex4pmCore.ProcessIR.Extractor.Reactor, as: ReactorExtractor

  describe "AutoFDE Reference Planner Reactor" do
    test "can be introspected into a ProcessIR partial order DAG" do
      ir = ReactorExtractor.extract(AutoFdePlannerReactor, id: "autofde_planner")

      assert ir.id == "autofde_planner"
      assert Map.has_key?(ir.activities, "primary_plan")
      assert Map.has_key?(ir.activities, "fallback_plan")
      assert Map.has_key?(ir.activities, "final")
      assert Map.has_key?(ir.partial_orders, "autofde_planner_dag")
    end
  end

  describe "real execution (Chicago-style: real executable scripts via Port.open, no mocking)" do
    setup do
      dir = Path.join(System.tmp_dir!(), "autofde_planner_reactor_test_#{Faker.UUID.v4()}")
      File.mkdir_p!(dir)

      write_script = fn name, body ->
        path = Path.join(dir, name)
        File.write!(path, "#!/bin/sh\n" <> body)
        File.chmod!(path, 0o755)
        path
      end

      on_exit(fn -> File.rm_rf!(dir) end)

      %{write_script: write_script, dir: dir}
    end

    test "runs the real primary script and returns its output when it succeeds", %{
      write_script: write_script
    } do
      run_id = Faker.UUID.v4()
      number = to_string(Faker.random_between(1, 1_000_000))
      primary = write_script.("primary_ok.sh", "read n\necho \"primary-result-$n\"\nexit 0\n")
      # fallback is never invoked on the happy path, but the reactor still needs a script
      # argument bound — point it at a script that would fail loudly if it were ever run.
      fallback =
        write_script.("fallback_unused.sh", "echo unexpected-fallback-invocation\nexit 1\n")

      assert {:ok, result} =
               Reactor.run(
                 AutoFdePlannerReactor,
                 %{
                   run_id: run_id,
                   number: number,
                   primary_script: primary,
                   fallback_script: fallback
                 },
                 %{}
               )

      assert result.source == :primary
      assert result.value == "primary-result-#{number}"
    end

    test "falls back to the real fallback script when the primary script exits non-zero, compensating the primary port",
         %{write_script: write_script} do
      run_id = Faker.UUID.v4()
      number = to_string(Faker.random_between(1, 1_000_000))
      primary = write_script.("primary_fail.sh", "read n\necho \"primary-failed-$n\"\nexit 1\n")
      fallback = write_script.("fallback_ok.sh", "read n\necho \"fallback-result-$n\"\nexit 0\n")

      assert {:ok, result} =
               Reactor.run(
                 AutoFdePlannerReactor,
                 %{
                   run_id: run_id,
                   number: number,
                   primary_script: primary,
                   fallback_script: fallback
                 },
                 %{}
               )

      assert result.source == :fallback
      assert result.value == "fallback-result-#{number}"
    end
  end
end
