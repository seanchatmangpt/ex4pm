defmodule Ex4pm.Integration.SelfConformanceReactorTest do
  use ExUnit.Case, async: false

  alias Ex4pmEngine.Reactors.SelfConformanceReactor

  @real_ocel_path "/Users/sac/xaas/priv/ocel/ash-actions.ndjson"

  describe "Autonomous Self-Conformance Reactor Execution" do
    test "executes full Reactor validation pipeline over real production OCEL 2.0 log" do
      if File.exists?(@real_ocel_path) do
        limit = 1000

        # Real, current line count of the live-growing external file, measured at
        # test-run time -- the reactor caps ingestion at `limit`, so the real expected
        # event count is min(real file size, limit), not a hardcoded 1000 that only
        # matched a past snapshot of this file.
        real_line_count =
          @real_ocel_path
          |> File.stream!()
          |> Enum.count(&(String.trim(&1) != ""))

        expected_events = min(real_line_count, limit)

        assert {:ok, report} =
                 Reactor.run(SelfConformanceReactor, %{
                   ocel_path: @real_ocel_path,
                   limit: limit,
                   target_ir: nil
                 })

        assert report.standing == :ALIVE
        assert report.total_events == expected_events
        assert report.discovered_activities >= 2
        assert report.conformance.fitness >= 0.85
        assert report.ocpq_satisfied == true
        assert report.median_duration_ms > 0
        assert String.contains?(report.earl_turtle, "earl:Assertion")
        assert is_struct(report.receipt, Ex4pmDomain.CapabilityReceipt)
      else
        # Fallback with inline synthetic NDJSON if file is absent in test environment
        tmp_path =
          Path.join(System.tmp_dir!(), "mock_ocel_#{System.unique_integer([:positive])}.ndjson")

        events = [
          %{
            "ocel:eid" => "e1",
            "ocel:activity" => "task.start",
            "ocel:timestamp" => "2026-01-01T00:00:00Z",
            "ocel:omap" => ["o1"]
          },
          %{
            "ocel:eid" => "e2",
            "ocel:activity" => "task.complete",
            "ocel:timestamp" => "2026-01-01T00:01:00Z",
            "ocel:omap" => ["o1"]
          }
        ]

        File.write!(tmp_path, Enum.map_join(events, "\n", &Jason.encode!/1))

        assert {:ok, report} =
                 Reactor.run(SelfConformanceReactor, %{
                   ocel_path: tmp_path,
                   limit: 10,
                   target_ir: nil
                 })

        assert report.standing == :ALIVE
        assert report.total_events == 2
      end
    end
  end
end
