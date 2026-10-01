defmodule Ex4pm.Integration.SelfConformanceReactorTest do
  use ExUnit.Case, async: false

  alias Ex4pmEngine.Reactors.SelfConformanceReactor

  @fixture_path Path.expand("../fixtures/ocel/self_conformance.ndjson", __DIR__)
  @live_ocel_path "/Users/sac/xaas/priv/ocel/ash-actions.ndjson"

  # Counts derived from the checked-in fixture itself, not hardcoded guesses.
  @fixture_events @fixture_path
                  |> File.read!()
                  |> String.split("\n", trim: true)
                  |> Enum.map(&Jason.decode!/1)
  @fixture_event_count length(@fixture_events)
  @fixture_activity_count @fixture_events
                          |> Enum.map(& &1["ocel:activity"])
                          |> Enum.uniq()
                          |> length()

  describe "Autonomous Self-Conformance Reactor Execution (hermetic fixture)" do
    test "executes full Reactor validation pipeline over checked-in OCEL ndjson fixture" do
      limit = 1000

      assert {:ok, report} =
               Reactor.run(SelfConformanceReactor, %{
                 ocel_path: @fixture_path,
                 limit: limit,
                 target_ir: nil
               })

      assert report.standing == :ALIVE
      assert report.total_events == min(@fixture_event_count, limit)
      assert report.discovered_activities == @fixture_activity_count
      assert report.conformance.fitness >= 0.85
      assert report.ocpq_satisfied == true
      assert report.median_duration_ms > 0
      assert String.contains?(report.earl_turtle, "earl:Assertion")
      assert is_struct(report.receipt, Ex4pmDomain.CapabilityReceipt)
    end
  end

  describe "live external OCEL log" do
    @describetag :live_external

    test "executes Reactor pipeline over the live-growing production OCEL log" do
      cond do
        not File.exists?(@live_ocel_path) ->
          IO.puts("SKIPPED live_external: #{@live_ocel_path} absent")

        not (File.stream!(@live_ocel_path)
             |> Enum.any?(&String.contains?(&1, "ProductionResource"))) ->
          IO.puts(
            "SKIPPED live_external: #{@live_ocel_path} lacks object type ProductionResource"
          )

        true ->
          limit = 1000

          expected =
            @live_ocel_path
            |> File.stream!()
            |> Enum.count(&(String.trim(&1) != ""))
            |> min(limit)

          assert {:ok, report} =
                   Reactor.run(SelfConformanceReactor, %{
                     ocel_path: @live_ocel_path,
                     limit: limit,
                     target_ir: nil
                   })

          assert report.standing == :ALIVE
          assert report.total_events == expected
      end
    end
  end
end
